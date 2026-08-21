package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"gopkg.in/yaml.v3"
)

var configPath = flag.String("config", "/app/config.yml", "Path to config YAML")

type Config struct {
	Platform              string   `yaml:"platform"`
	EmergencyPlatforms    []string `yaml:"emergency_platforms"` // для событий (actual/planned); если пусто — используется platform
	APIBaseURL            string   `yaml:"api_base_url"`
	ScrapeIntervalSeconds int      `yaml:"scrape_interval_seconds"`
}

func loadConfig(path string) (*Config, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var c Config
	if err := yaml.NewDecoder(f).Decode(&c); err != nil {
		return nil, err
	}
	if c.Platform == "" {
		c.Platform = "advanced"
	}
	if c.APIBaseURL == "" {
		c.APIBaseURL = "https://api.cloud.ru"
	}
	return &c, nil
}

// API response types (Cloud.ru Status API)
type serviceAvailabilityResponse struct {
	Success bool `json:"success"`
	Data    []struct {
		ID       string `json:"id"`
		Title    string `json:"title"`
		Status   string `json:"status"`
		Platform string `json:"platform"`
		Timeline []struct {
			StartAt string `json:"startAt"`
			EndAt   string `json:"endAt"`
			Status  string `json:"status"`
		} `json:"timeline"`
	} `json:"data"`
}

type emergencyEvent struct {
	ID              string   `json:"id"`
	Title           string   `json:"title"`
	Description     string   `json:"description"`
	Status          string   `json:"status"`
	Type            string   `json:"type"`
	StartAt         string   `json:"startAt"`
	EndAt           string   `json:"endAt"`
	Inaccessibility string   `json:"inaccessibility"`
	Service         []string `json:"service"`
	Platforms       []string `json:"platforms"`
	PD              []string `json:"pd"`
}

type emergencyResponse struct {
	Success bool `json:"success"`
	Data    struct {
		Actual    []emergencyEvent `json:"actual"`
		Planned   []emergencyEvent `json:"planned"`
		Completed []emergencyEvent `json:"completed"`
	} `json:"data"`
}

type collector struct {
	config *Config
	client *http.Client

	serviceStatus   *prometheus.GaugeVec
	emergencyActual *prometheus.GaugeVec
	emergencyCount  *prometheus.GaugeVec
}

func newCollector(cfg *Config) *collector {
	return &collector{
		config: cfg,
		client: &http.Client{Timeout: 30 * time.Second},
		serviceStatus: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "cloud_ru_service_availability_status",
				Help: "Current status of Cloud.ru service (1=success, 0=partial, 2=failed).",
			},
			[]string{"platform", "service_id", "title"},
		),
		emergencyActual: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "cloud_ru_emergency_event_info",
				Help: "Emergency/planned work event (1=present). Full description: https://cloud.ru/status/events",
			},
			[]string{"id", "title", "description", "status", "event_type", "service", "start_at", "end_at", "inaccessibility"},
		),
		emergencyCount: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "cloud_ru_emergency_events_total",
				Help: "Number of emergency events by category (actual, planned). Completed events are not collected.",
			},
			[]string{"category"},
		),
	}
}

func statusToValue(s string) float64 {
	switch strings.ToLower(s) {
	case "success":
		return 1
	case "partial":
		return 0
	case "failed":
		return 2
	default:
		return -1
	}
}

func (c *collector) fetchServiceAvailability() error {
	url := strings.TrimSuffix(c.config.APIBaseURL, "/") + "/content/v1/service_availability?platform=" + c.config.Platform
	resp, err := c.client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	var data serviceAvailabilityResponse
	if err := json.Unmarshal(body, &data); err != nil {
		return err
	}
	if !data.Success {
		return fmt.Errorf("API returned success=false")
	}

	c.serviceStatus.Reset()
	for _, svc := range data.Data {
		if svc.Platform != c.config.Platform {
			continue
		}
		v := statusToValue(svc.Status)
		c.serviceStatus.WithLabelValues(safeLabel(svc.Platform, 32), safeLabel(svc.ID, 64), safeLabel(svc.Title, 80)).Set(v)
	}
	return nil
}

func (c *collector) fetchEmergency() error {
	platforms := c.config.EmergencyPlatforms
	if len(platforms) == 0 {
		platforms = []string{c.config.Platform}
	}

	// API при ?platform=evolution/vmware возвращает ответ БЕЗ ключа "data" (только success/lang/resultCode).
	// Полные actual/planned приходят только без параметра platform — делаем один запрос и фильтруем сами.
	url := strings.TrimSuffix(c.config.APIBaseURL, "/") + "/naumengateway/v1/emergency"
	resp, err := c.client.Get(url)
	if err != nil {
		log.Printf("fetch emergency: %v", err)
		return err
	}
	body, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		log.Printf("read emergency: %v", err)
		return err
	}
	if resp.StatusCode != http.StatusOK {
		log.Printf("emergency: HTTP %d", resp.StatusCode)
		return nil
	}
	var data emergencyResponse
	if err := json.Unmarshal(body, &data); err != nil {
		log.Printf("parse emergency: %v", err)
		return err
	}
	if !data.Success {
		log.Printf("emergency: API success=false")
		return nil
	}
	actualRaw := data.Data.Actual
	plannedRaw := data.Data.Planned
	if actualRaw == nil {
		actualRaw = []emergencyEvent{}
	}
	if plannedRaw == nil {
		plannedRaw = []emergencyEvent{}
	}

	var allActual, allPlanned []emergencyEvent
	for _, platform := range platforms {
		platform = strings.TrimSpace(platform)
		actual := filterByPlatform(actualRaw, platform)
		planned := filterByPlatform(plannedRaw, platform)
		log.Printf("emergency platform=%s: raw actual=%d planned=%d, after filter actual=%d planned=%d", platform, len(actualRaw), len(plannedRaw), len(actual), len(planned))
		allActual = append(allActual, actual...)
		allPlanned = append(allPlanned, planned...)
	}
	// Дедуп по ID (один и тот же event может попасть при нескольких платформах)
	allActual = dedupeEvents(allActual)
	allPlanned = dedupeEvents(allPlanned)

	c.emergencyCount.Reset()
	c.emergencyActual.Reset()

	c.emergencyCount.WithLabelValues("actual").Set(float64(len(allActual)))
	c.emergencyCount.WithLabelValues("planned").Set(float64(len(allPlanned)))

	for _, e := range allActual {
		c.emergencyActual.WithLabelValues(safeLabel(e.ID, 64), safeLabel(e.Title, 80), safeLabel(e.Description, 400), safeLabel(e.Status, 32), safeLabel(e.Type, 64), safeLabel(strings.Join(e.Service, ","), 120), safeLabel(e.StartAt, 32), safeLabel(e.EndAt, 32), safeLabel(e.Inaccessibility, 32)).Set(1)
	}
	for _, e := range allPlanned {
		c.emergencyActual.WithLabelValues(safeLabel(e.ID, 64), safeLabel(e.Title, 80), safeLabel(e.Description, 400), safeLabel(e.Status, 32), safeLabel(e.Type, 64), safeLabel(strings.Join(e.Service, ","), 120), safeLabel(e.StartAt, 32), safeLabel(e.EndAt, 32), safeLabel(e.Inaccessibility, 32)).Set(1)
	}
	return nil
}

func dedupeEvents(events []emergencyEvent) []emergencyEvent {
	seen := make(map[string]bool)
	var out []emergencyEvent
	for _, e := range events {
		if seen[e.ID] {
			continue
		}
		seen[e.ID] = true
		out = append(out, e)
	}
	return out
}

func filterByPlatform(events []emergencyEvent, platform string) []emergencyEvent {
	// API returns all platforms; filter to only events that mention our platform in e.Platforms.
	var out []emergencyEvent
	needle := strings.ToLower(platform)
	for _, e := range events {
		for _, p := range e.Platforms {
			if strings.Contains(strings.ToLower(p), needle) {
				out = append(out, e)
				break
			}
		}
	}
	return out
}

func truncate(s string, max int) string {
	if max <= 0 || s == "" {
		return s
	}
	// Обрезка только по рунам, чтобы не резать многобайтовый символ (иначе в лейбл попадает невалидный UTF-8 и panic).
	if !utf8.ValidString(s) {
		s = strings.ToValidUTF8(s, "?")
	}
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	runes := []rune(s)
	return string(runes[:max])
}

// safeLabel гарантирует валидный UTF-8 и ограниченную длину для лейблов Prometheus.
func safeLabel(s string, maxLen int) string {
	if s == "" {
		return ""
	}
	s = strings.ToValidUTF8(s, "?")
	s = truncate(s, maxLen)
	return strings.ToValidUTF8(s, "?")
}

func (c *collector) Describe(ch chan<- *prometheus.Desc) {
	c.serviceStatus.Describe(ch)
	c.emergencyActual.Describe(ch)
	c.emergencyCount.Describe(ch)
}

func (c *collector) Collect(ch chan<- prometheus.Metric) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("collect panic: %v", r)
		}
	}()
	if err := c.fetchServiceAvailability(); err != nil {
		log.Printf("fetch service_availability: %v", err)
	}
	if err := c.fetchEmergency(); err != nil {
		log.Printf("fetch emergency: %v", err)
	}
	c.serviceStatus.Collect(ch)
	c.emergencyActual.Collect(ch)
	c.emergencyCount.Collect(ch)
}

func main() {
	flag.Parse()
	cfg, err := loadConfig(*configPath)
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	emergencyPlat := cfg.EmergencyPlatforms
	if len(emergencyPlat) == 0 {
		emergencyPlat = []string{cfg.Platform}
	}
	log.Printf("config: platform=%s emergency_platforms=%v api=%s", cfg.Platform, emergencyPlat, cfg.APIBaseURL)

	reg := prometheus.NewRegistry()
	reg.MustRegister(newCollector(cfg))

	http.Handle("/metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{Registry: reg}))
	http.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte("Cloud.ru Status Exporter\nMetrics: /metrics\nHealth: /health\n"))
	})

	addr := ":" + strconv.Itoa(8087)
	log.Printf("listening on %s", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatal(err)
	}
}
