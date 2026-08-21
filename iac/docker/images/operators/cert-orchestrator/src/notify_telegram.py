"""Telegram Bot API: sendMessage, parse_mode HTML, эмодзи в заголовках и сводках."""

from __future__ import annotations

import asyncio
import json
import logging
import os
import socket
from datetime import datetime
from typing import List, Optional, Tuple

import aiohttp

from config import OrchestratorConfig, TelegramNotifyOnConfig

logger = logging.getLogger(__name__)

APP_VERSION = (os.environ.get("CERT_ORCHESTRATOR_VERSION") or "1.0").strip()


def telegram_enabled(cfg: OrchestratorConfig) -> bool:
    t = cfg.telegram
    return bool((t.bot_token or "").strip() and t.chat_ids)


def _flag(notify: TelegramNotifyOnConfig, name: str) -> bool:
    return bool(getattr(notify, name, True))


def _escape_html(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class TelegramClient:
    def __init__(self, cfg: OrchestratorConfig):
        self.cfg = cfg
        self.bot_token = (cfg.telegram.bot_token or "").strip()
        self.chat_ids = [c.strip() for c in cfg.telegram.chat_ids if (c or "").strip()]
        self.api_url = f"https://api.telegram.org/bot{self.bot_token}"

    def _client_timeout(self) -> aiohttp.ClientTimeout:
        t = self.cfg.telegram
        return aiohttp.ClientTimeout(
            total=t.total_timeout_seconds,
            connect=t.connect_timeout_seconds,
        )

    async def _request_with_retry(
        self,
        method: str,
        url: str,
        *,
        max_attempts: Optional[int] = None,
        **kwargs,
    ):
        """HTTP к Telegram API через VPS (extra_hosts + IPv4)."""
        if max_attempts is None:
            max_attempts = self.cfg.telegram.retry_attempts
        last_error = None
        for attempt in range(1, max_attempts + 1):
            try:
                connector = aiohttp.TCPConnector(family=socket.AF_INET)
                async with aiohttp.ClientSession(
                    connector=connector,
                    timeout=self._client_timeout(),
                ) as session:
                    http_call = getattr(session, method)
                    async with http_call(url, **kwargs) as response:
                        body = await response.read()
                        if attempt > 1:
                            logger.info(
                                "Telegram request OK after %s attempts",
                                attempt,
                            )
                        return response.status, body
            except Exception as exc:
                last_error = exc
                if attempt < max_attempts:
                    logger.warning(
                        "Telegram request failed (attempt %s/%s): %s; retry in %ss",
                        attempt,
                        max_attempts,
                        exc,
                        self.cfg.telegram.retry_delay_seconds,
                    )
                    await asyncio.sleep(self.cfg.telegram.retry_delay_seconds)
                else:
                    logger.error(
                        "Telegram request failed after %s attempts: %s",
                        max_attempts,
                        exc,
                    )
        raise last_error

    async def test_connection(self) -> bool:
        if not self.bot_token:
            return False
        url = f"{self.api_url}/getMe"
        try:
            status, body = await self._request_with_retry("get", url, max_attempts=1)
            if status != 200:
                return False
            result = json.loads(body)
            return bool(result.get("ok"))
        except Exception as e:
            logger.warning("Telegram getMe: %s", e)
            return False

    async def _send_single_message(self, chat_id: str, message: str) -> None:
        url = f"{self.api_url}/sendMessage"
        payload = {
            "chat_id": chat_id,
            "text": message,
            "parse_mode": "HTML",
            "disable_web_page_preview": True,
        }
        status, body = await self._request_with_retry("post", url, json=payload)
        if status != 200:
            raise RuntimeError(f"HTTP {status}: {body.decode('utf-8', errors='replace')}")
        result = json.loads(body)
        if not result.get("ok"):
            raise RuntimeError(result.get("description", "Telegram API error"))

    async def _send_message(self, message: str) -> None:
        if len(message) > 4096:
            chunks = self._split_message(message, 4000)
        else:
            chunks = [message]
        for chat_id in self.chat_ids:
            for i, chunk in enumerate(chunks):
                if i > 0:
                    chunk = f"<i>Продолжение {i + 1}/{len(chunks)}</i>\n\n{chunk}"
                await self._send_single_message(chat_id, chunk)
                await asyncio.sleep(0.5)

    def _split_message(self, message: str, max_length: int) -> List[str]:
        chunks: List[str] = []
        lines = message.split("\n")
        current = ""
        for line in lines:
            if len(current) + len(line) + 1 > max_length and current:
                chunks.append(current.rstrip())
                current = line + "\n"
            else:
                current += line + "\n"
        if current.strip():
            chunks.append(current.rstrip())
        return chunks

    def _header(self, emoji: str, title: str, status_line: str) -> str:
        ts = datetime.now().strftime("%d.%m.%Y %H:%M:%S")
        return (
            f"{emoji} <b>{title}</b>\n"
            f"📊 <b>Статус:</b> {status_line}\n"
            f"🕐 <b>Время:</b> {ts}\n"
        )

    async def send_startup(self) -> None:
        if not telegram_enabled(self.cfg) or not _flag(self.cfg.telegram.notify_on, "container_start"):
            return
        c = self.cfg
        msg = self._header("✅", "Cert Orchestrator", "ЗАПУЩЕН")
        msg += f"\n📋 <b>Окружение:</b> {_escape_html(c.meta.environment)}\n"
        msg += f"🌐 <b>Домен:</b> <code>{_escape_html((c.letsencrypt.domain or '').strip() or '—')}</code>\n"
        msg += f"📅 <b>Расписание:</b> {c.schedule.weekday} {c.schedule.time_hhmm} ({c.meta.timezone})\n"
        msg += f"⏳ <b>Интервал:</b> раз в {c.schedule.days_interval} дн.\n"
        msg += f"\n🤖 <b>Cert Orchestrator v{APP_VERSION}</b>"
        await self._send_message(msg)

    async def send_renewal_started(self) -> None:
        if not telegram_enabled(self.cfg) or not _flag(self.cfg.telegram.notify_on, "renewal_started"):
            return
        d = (self.cfg.letsencrypt.domain or "").strip() or "—"
        msg = self._header("🔄", "Cert Orchestrator", "ОБНОВЛЕНИЕ TLS")
        msg += f"\n🔐 <b>Домен:</b> <code>{_escape_html(d)}</code>\n"
        msg += f"\n🤖 <b>Cert Orchestrator v{APP_VERSION}</b>"
        await self._send_message(msg)

    async def send_renewal_error(self, step: str, detail: str) -> None:
        if not telegram_enabled(self.cfg) or not _flag(self.cfg.telegram.notify_on, "errors"):
            return
        msg = self._header("🚨", "Cert Orchestrator", "ОШИБКА")
        msg += f"\n⚠️ <b>Этап:</b> {_escape_html(step)}\n"
        msg += f"📝 <b>Детали:</b>\n<pre>{_escape_html(detail[:3500])}</pre>\n"
        msg += f"\n🤖 <b>Cert Orchestrator v{APP_VERSION}</b>"
        await self._send_message(msg)

    async def send_renewal_finished(
        self,
        step_lines: List[Tuple[str, bool, str]],
        https_lines: Optional[List[Tuple[str, bool, str, str]]] = None,
        *,
        partial: bool = False,
        full_success: bool = True,
    ) -> None:
        if not telegram_enabled(self.cfg) or not _flag(self.cfg.telegram.notify_on, "renewal_finished"):
            return
        if full_success:
            status = "ОБНОВЛЕНИЕ ЗАВЕРШЕНО"
            emoji = "✅"
        elif partial:
            status = "ЧАСТИЧНОЕ ОБНОВЛЕНИЕ"
            emoji = "⚠️"
        else:
            status = "ОБНОВЛЕНИЕ НЕ УДАЛОСЬ"
            emoji = "🚨"
        msg = self._header(emoji, "Cert Orchestrator", status)
        d = (self.cfg.letsencrypt.domain or "").strip() or "—"
        msg += f"\n🔐 <b>Домен:</b> <code>{_escape_html(d)}</code>\n\n"
        msg += "📈 <b>Сводка этапов:</b>\n"
        for name, ok, note in step_lines:
            em = "🟢" if ok else "🔴"
            msg += f"{em} <b>{_escape_html(name)}</b>"
            if note:
                msg += f" — {_escape_html(note)}"
            msg += "\n"
        if https_lines and _flag(self.cfg.telegram.notify_on, "per_host_result"):
            msg += "\n📋 <b>Проверка HTTPS:</b>\n"
            for hp, ok, meta, extra in https_lines:
                em = "🟢" if ok else "❌"
                msg += f"{em} <code>{_escape_html(hp)}</code>\n"
                if meta:
                    msg += f"   📅 {_escape_html(meta)}\n"
                if extra:
                    msg += f"   🔑 SHA-256: <code>{_escape_html(extra)}</code>\n"
        msg += f"\n🤖 <b>Cert Orchestrator v{APP_VERSION}</b>"
        await self._send_message(msg)

    async def send_renewal_success(
        self,
        step_lines: List[Tuple[str, bool, str]],
        https_lines: Optional[List[Tuple[str, bool, str, str]]] = None,
    ) -> None:
        await self.send_renewal_finished(
            step_lines, https_lines, partial=False, full_success=True
        )

    async def send_next_rotation_reminder(self) -> None:
        if not telegram_enabled(self.cfg) or not _flag(self.cfg.telegram.notify_on, "next_rotation_reminder"):
            return
        s = self.cfg.schedule
        msg = self._header("📅", "Cert Orchestrator", "СЛЕДУЮЩАЯ РОТАЦИЯ")
        msg += f"\n• Окно: <b>{_escape_html(s.weekday)}</b> {_escape_html(s.time_hhmm)} ({_escape_html(self.cfg.meta.timezone)})\n"
        msg += f"• Следующая попытка не ранее чем через <b>{s.days_interval}</b> дн. после последнего прогона\n"
        msg += f"\n🤖 <b>Cert Orchestrator v{APP_VERSION}</b>"
        await self._send_message(msg)


def _run_safe(coro) -> None:
    try:
        asyncio.run(coro)
    except Exception as e:
        logger.warning("Telegram: %s", e)


def notify_startup(cfg: OrchestratorConfig) -> None:
    if not telegram_enabled(cfg):
        return
    _run_safe(TelegramClient(cfg).send_startup())


def notify_renewal_started(cfg: OrchestratorConfig) -> None:
    if not telegram_enabled(cfg):
        return
    _run_safe(TelegramClient(cfg).send_renewal_started())


def notify_renewal_error(cfg: OrchestratorConfig, step: str, detail: str) -> None:
    if not telegram_enabled(cfg):
        return
    _run_safe(TelegramClient(cfg).send_renewal_error(step, detail))


def notify_renewal_finished(
    cfg: OrchestratorConfig,
    step_lines: List[Tuple[str, bool, str]],
    https_lines: Optional[List[Tuple[str, bool, str, str]]] = None,
    *,
    partial: bool = False,
    full_success: bool = True,
) -> None:
    if not telegram_enabled(cfg):
        return
    _run_safe(
        TelegramClient(cfg).send_renewal_finished(
            step_lines, https_lines, partial=partial, full_success=full_success
        )
    )


def notify_renewal_success(
    cfg: OrchestratorConfig,
    step_lines: List[Tuple[str, bool, str]],
    https_lines: Optional[List[Tuple[str, bool, str, str]]] = None,
) -> None:
    notify_renewal_finished(cfg, step_lines, https_lines, partial=False, full_success=True)


def notify_next_rotation_reminder(cfg: OrchestratorConfig) -> None:
    if not telegram_enabled(cfg):
        return
    _run_safe(TelegramClient(cfg).send_next_rotation_reminder())


async def test_telegram_async(cfg: OrchestratorConfig) -> bool:
    if not telegram_enabled(cfg):
        return False
    return await TelegramClient(cfg).test_connection()
