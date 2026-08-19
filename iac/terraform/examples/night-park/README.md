# Night park / weekday start (pattern)

Sanitized sketch of a **non-prod** stop/start calendar. Attach to Huawei-class ECS/CCE or AWS instances. **Do not** point this at production without an explicit allow-list.

Business story: [`../../../architecture/02-finops-night-park.md`](../../../architecture/02-finops-night-park.md).

`schedule.example.yaml` is inputs only. Wire it to the cloud scheduler or a CI cron that calls the provider stop/start API. Account IDs stay out.
