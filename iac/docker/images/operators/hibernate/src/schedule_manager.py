#!/usr/bin/env python3
"""
Schedule Manager module for CCE/ECS Cluster Hibernate/Awake Management
Handles scheduling of cluster operations using simplified format:
off from <time> to <time> <day/date>
"""

import re
import time
import threading
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime, timedelta
from dateutil import parser as date_parser
from dateutil.relativedelta import relativedelta
import calendar
from config import config, ClusterConfig, ECSInstanceConfig
from logger import logger
from cluster_manager import cluster_manager
from ecs_instance_manager import ecs_instance_manager
import asyncio

class ScheduleManager:
    """Manages scheduled cluster operations"""
    
    # Day names mapping
    DAYS_MAP = {
        'monday': 0, 'mon': 0,
        'tuesday': 1, 'tue': 1, 'tues': 1,
        'wednesday': 2, 'wed': 2, 'wendsday': 2,  # Support typo
        'thursday': 3, 'thu': 3, 'thurs': 3,
        'friday': 4, 'fri': 4,
        'saturday': 5, 'sat': 5,
        'sunday': 6, 'sun': 6
    }
    
    def __init__(self):
        """Initialize Schedule Manager"""
        self.scheduler_thread: Optional[threading.Thread] = None
        self.running = False
        self.schedules: Dict[str, List[Dict]] = {}  # cluster_id_operation -> list of schedule rules
        self.check_interval = 60  # Check every minute
        # Track schedule overrides: cluster_id -> {'until': timestamp, 'reason': str}
        self.schedule_overrides: Dict[str, Dict[str, Any]] = {}
        # Lock for thread-safe access to overrides
        self.overrides_lock = threading.Lock()
    
    def parse_schedule_string(self, schedule_str: str) -> Optional[Dict]:
        """
        Parse schedule string in format: from <time> [<day/date>] to <time> [<day/date>]
        
        Examples:
        - "from 22:00 to 8:00 monday"
        - "from 23:00 to 09:00 wednesday"
        - "from 15:00 friday to 08:00 monday"
        - "from 15:00 22.01.26 to 20:00 25.01.26"
        
        Also supports legacy format with "off": "off from ..."
        
        Returns dict with:
        - start_time: datetime or time
        - end_time: datetime or time
        - start_day: optional day name or date
        - end_day: optional day name or date
        - is_recurring: bool (True for day names, False for dates)
        """
        if not schedule_str:
            return None
        
        schedule_str = schedule_str.strip().lower()
        
        # Remove "off" if present (legacy format support)
        schedule_str = re.sub(r'^off\s+', '', schedule_str)
        
        # Pattern: from <time> [<day/date>] to <time> [<day/date>]
        # Supports both: "from 22:00 to 8:00 monday" and "from 22:00 monday to 8:00 tuesday"
        pattern = r'from\s+(\d{1,2}:\d{2})\s+(\w+|\d{1,2}\.\d{1,2}\.\d{2,4})?\s+to\s+(\d{1,2}:\d{2})\s+(\w+|\d{1,2}\.\d{1,2}\.\d{2,4})?'
        match = re.match(pattern, schedule_str)
        
        if not match:
            logger.warning(f"Invalid schedule format: {schedule_str}")
            return None
        
        start_time_str = match.group(1)
        start_day_str = match.group(2)
        end_time_str = match.group(3)
        end_day_str = match.group(4)
        
        # If end_day is None but there's text after end_time, try to extract it
        # This handles "from 22:00 to 8:00 monday" format where day is only at the end
        if not end_day_str and not start_day_str:
            # Try to find day/date at the end of the string
            remaining = schedule_str[len(match.group(0)):].strip()
            if remaining:
                # Check if it's a day name or date
                if remaining in self.DAYS_MAP or remaining in [d.lower() for d in calendar.day_name]:
                    end_day_str = remaining
                elif re.match(r'\d{1,2}\.\d{1,2}\.\d{2,4}', remaining):
                    end_day_str = remaining
        
        try:
            # Parse times
            start_time = datetime.strptime(start_time_str, '%H:%M').time()
            end_time = datetime.strptime(end_time_str, '%H:%M').time()
            
            # Determine if recurring (day names) or specific dates
            is_recurring = False
            start_day = None
            end_day = None
            
            if start_day_str:
                # Check if it's a day name or date
                if start_day_str in self.DAYS_MAP or start_day_str in [d.lower() for d in calendar.day_name]:
                    is_recurring = True
                    start_day = start_day_str
                else:
                    # Try to parse as date
                    try:
                        # Support formats: 22.01.26, 22.01.2026
                        if '.' in start_day_str:
                            parts = start_day_str.split('.')
                            if len(parts) == 3:
                                day, month, year = parts
                                if len(year) == 2:
                                    year = '20' + year
                                start_day = datetime(int(year), int(month), int(day))
                            else:
                                logger.warning(f"Invalid date format: {start_day_str}")
                                return None
                        else:
                            start_day = date_parser.parse(start_day_str)
                    except Exception as e:
                        logger.warning(f"Could not parse start date: {start_day_str}, error: {e}")
                        return None
            
            if end_day_str:
                if end_day_str in self.DAYS_MAP or end_day_str in [d.lower() for d in calendar.day_name]:
                    is_recurring = True
                    end_day = end_day_str
                else:
                    try:
                        if '.' in end_day_str:
                            parts = end_day_str.split('.')
                            if len(parts) == 3:
                                day, month, year = parts
                                if len(year) == 2:
                                    year = '20' + year
                                end_day = datetime(int(year), int(month), int(day))
                            else:
                                logger.warning(f"Invalid date format: {end_day_str}")
                                return None
                        else:
                            end_day = date_parser.parse(end_day_str)
                    except Exception as e:
                        logger.warning(f"Could not parse end date: {end_day_str}, error: {e}")
                        return None
            
            return {
                'start_time': start_time,
                'end_time': end_time,
                'start_day': start_day,
                'end_day': end_day,
                'is_recurring': is_recurring,
                'original': schedule_str
            }
            
        except Exception as e:
            logger.error(f"Error parsing schedule: {schedule_str}, error: {e}")
            return None
    
    def parse_schedules(self, schedule_str: str) -> List[Dict]:
        """
        Parse multiple schedules separated by newlines or semicolons
        Returns list of parsed schedule dicts
        """
        if not schedule_str:
            return []
        
        # Split by newline or semicolon
        schedules = re.split(r'[\n;]', schedule_str)
        parsed = []
        
        for sched in schedules:
            sched = sched.strip()
            if sched:
                parsed_sched = self.parse_schedule_string(sched)
                if parsed_sched:
                    parsed.append(parsed_sched)
        
        return parsed
    
    def is_time_in_range(self, check_time: datetime, schedule_rule: Dict) -> bool:
        """
        Check if current time matches the schedule rule
        """
        current_time = check_time.time()
        start_time = schedule_rule['start_time']
        end_time = schedule_rule['end_time']
        start_day = schedule_rule.get('start_day')
        end_day = schedule_rule.get('end_day')
        is_recurring = schedule_rule['is_recurring']
        
        if is_recurring:
            # Recurring schedule (day names)
            current_weekday = check_time.weekday()
            
            if start_day and end_day:
                # Range of days (e.g., friday to monday)
                start_weekday = self.DAYS_MAP.get(start_day.lower(), None)
                end_weekday = self.DAYS_MAP.get(end_day.lower(), None)
                
                if start_weekday is None or end_weekday is None:
                    return False
                
                # Handle wrap-around (e.g., friday to monday)
                if start_weekday > end_weekday:
                    # Weekend wrap-around (e.g., friday to monday)
                    day_match = current_weekday >= start_weekday or current_weekday <= end_weekday
                else:
                    # Normal range (e.g., monday to friday)
                    day_match = start_weekday <= current_weekday <= end_weekday
                
                if not day_match:
                    return False
                
                # Check time range based on which day we're on
                if start_weekday == current_weekday:
                    # On start day, check if time >= start_time
                    return current_time >= start_time
                elif end_weekday == current_weekday:
                    # On end day, check if time <= end_time
                    return current_time <= end_time
                else:
                    # Between start and end days, always true (full days)
                    return True
                    
            elif start_day:
                # Single day or overnight range
                target_weekday = self.DAYS_MAP.get(start_day.lower(), None)
                if target_weekday is None:
                    return False
                
                # Check if time is in range (handle wrap-around to next day)
                if start_time <= end_time:
                    # Same day range (e.g., 10:00 to 18:00)
                    if current_weekday != target_weekday:
                        return False
                    return start_time <= current_time <= end_time
                else:
                    # Overnight range (e.g., 23:00 to 09:00)
                    # Check if we're on start day (after start_time) or next day (before end_time)
                    if current_weekday == target_weekday:
                        # On start day - check if time >= start_time
                        return current_time >= start_time
                    elif current_weekday == (target_weekday + 1) % 7:
                        # On next day - check if time <= end_time
                        return current_time <= end_time
                    else:
                        return False
            else:
                # No day specified, check time only
                if start_time <= end_time:
                    return start_time <= current_time <= end_time
                else:
                    # Overnight range
                    return current_time >= start_time or current_time <= end_time
        else:
            # Specific dates
            if start_day and isinstance(start_day, datetime):
                start_datetime = datetime.combine(start_day.date(), start_time)
            else:
                start_datetime = datetime.combine(check_time.date(), start_time)
            
            if end_day and isinstance(end_day, datetime):
                end_datetime = datetime.combine(end_day.date(), end_time)
            else:
                # If end_time is earlier than start_time, assume next day
                if end_time < start_time:
                    end_datetime = datetime.combine(check_time.date() + timedelta(days=1), end_time)
                else:
                    end_datetime = datetime.combine(check_time.date(), end_time)
            
            return start_datetime <= check_time <= end_datetime
    
    def should_hibernate(self, cluster: ClusterConfig, check_time: Optional[datetime] = None) -> bool:
        """Check if cluster should be hibernated at given time"""
        if not cluster.hibernate_schedule:
            return False
        
        if check_time is None:
            check_time = datetime.now()
        
        schedules = self.parse_schedules(cluster.hibernate_schedule)
        for schedule_rule in schedules:
            if self.is_time_in_range(check_time, schedule_rule):
                return True
        
        return False
    
    def should_awake(self, cluster: ClusterConfig, check_time: Optional[datetime] = None) -> bool:
        """
        Check if cluster should be awoken at given time
        Logic: Cluster should be awake if:
        1. There's no hibernate_schedule (always awake)
        2. Current time is NOT in any hibernate_schedule period
        3. After a hibernate period ends, if next hibernate doesn't start immediately, wake up
        """
        if check_time is None:
            check_time = datetime.now()
        
        # If no hibernate schedule, cluster should always be awake
        if not cluster.hibernate_schedule:
            return True
        
        # Check if current time is in any hibernate period
        schedules = self.parse_schedules(cluster.hibernate_schedule)
        
        # If time is NOT in any hibernate schedule, cluster should be awake
        for schedule_rule in schedules:
            if self.is_time_in_range(check_time, schedule_rule):
                # Currently in hibernate period, don't awake
                return False
        
        # Time is not in any hibernate period, cluster should be awake
        return True
    
    def should_stop(self, instance: ECSInstanceConfig, check_time: Optional[datetime] = None) -> bool:
        """Check if ECS instance should be stopped at given time"""
        if not instance.hibernate_schedule:
            return False
        
        if check_time is None:
            check_time = datetime.now()
        
        schedules = self.parse_schedules(instance.hibernate_schedule)
        for schedule_rule in schedules:
            if self.is_time_in_range(check_time, schedule_rule):
                return True
        
        return False
    
    def should_start(self, instance: ECSInstanceConfig, check_time: Optional[datetime] = None) -> bool:
        """
        Check if ECS instance should be started at given time
        Logic: Instance should be started if:
        1. There's no hibernate_schedule (always running)
        2. Current time is NOT in any hibernate_schedule period
        """
        if check_time is None:
            check_time = datetime.now()
        
        # If no hibernate schedule, instance should always be running
        if not instance.hibernate_schedule:
            return True
        
        # Check if current time is in any hibernate period
        schedules = self.parse_schedules(instance.hibernate_schedule)
        
        # If time is NOT in any hibernate schedule, instance should be running
        for schedule_rule in schedules:
            if self.is_time_in_range(check_time, schedule_rule):
                # Currently in hibernate period, don't start
                return False
        
        # Time is not in any hibernate period, instance should be running
        return True
    
    def validate_schedules_overlap(self, schedules: List[str]) -> Tuple[bool, List[str]]:
        """
        Validate that schedules don't overlap
        Returns (is_valid, list_of_warnings)
        """
        warnings = []
        parsed_schedules = []
        
        for sched_str in schedules:
            parsed = self.parse_schedules(sched_str)
            parsed_schedules.extend(parsed)
        
        # Check for overlaps (simplified - check if any two schedules overlap)
        # This is a basic check - full validation would require checking all time ranges
        for i, sched1 in enumerate(parsed_schedules):
            for j, sched2 in enumerate(parsed_schedules[i+1:], i+1):
                # Check if schedules overlap
                # This is simplified - full overlap detection would be more complex
                if sched1['is_recurring'] == sched2['is_recurring']:
                    if sched1['is_recurring']:
                        # Both recurring - check day overlap
                        if sched1.get('start_day') and sched2.get('start_day'):
                            day1 = self.DAYS_MAP.get(sched1['start_day'].lower())
                            day2 = self.DAYS_MAP.get(sched2['start_day'].lower())
                            if day1 == day2:
                                # Same day - check time overlap
                                if self._times_overlap(sched1['start_time'], sched1['end_time'],
                                                       sched2['start_time'], sched2['end_time']):
                                    warnings.append(f"Пересечение расписаний: '{sched1['original']}' и '{sched2['original']}'")
        
        return (len(warnings) == 0, warnings)
    
    def _times_overlap(self, start1: time, end1: time, start2: time, end2: time) -> bool:
        """Check if two time ranges overlap"""
        # Convert to datetime for comparison (using same date)
        base_date = datetime(2000, 1, 1)
        dt_start1 = datetime.combine(base_date, start1)
        dt_end1 = datetime.combine(base_date, end1)
        dt_start2 = datetime.combine(base_date, start2)
        dt_end2 = datetime.combine(base_date, end2)
        
        # Handle overnight ranges
        if dt_end1 < dt_start1:
            dt_end1 += timedelta(days=1)
        if dt_end2 < dt_start2:
            dt_end2 += timedelta(days=1)
        
        return not (dt_end1 <= dt_start2 or dt_end2 <= dt_start1)
    
    def setup_cluster_schedules(self):
        """Setup schedules for all configured clusters and ECS instances"""
        if not config.schedule_enabled:
            logger.info("Scheduling is disabled")
            return
        
        logger.info("Setting up cluster and ECS instance schedules...")
        
        # Setup cluster schedules
        for cluster in config.clusters:
            cluster_id = cluster.cluster_id
            cluster_name = cluster.name
            
            # Parse and store schedules
            if cluster.hibernate_schedule:
                schedules = self.parse_schedules(cluster.hibernate_schedule)
                self.schedules[f"{cluster_id}_hibernate"] = schedules
                logger.info(f"Hibernate schedules for cluster {cluster_name}: {len(schedules)} rules")
                logger.info(f"Awake logic: Cluster will be awake when NOT in hibernate periods")
        
        # Setup ECS instance schedules
        for instance in config.ecs_instances:
            instance_id = instance.instance_id
            instance_name = instance.name
            
            # Parse and store schedules
            if instance.hibernate_schedule:
                schedules = self.parse_schedules(instance.hibernate_schedule)
                self.schedules[f"instance_{instance_id}_stop"] = schedules
                logger.info(f"Stop schedules for ECS instance {instance_name}: {len(schedules)} rules")
                logger.info(f"Start logic: Instance will be running when NOT in hibernate periods")
        
        logger.info(f"Setup schedules for {len(self.schedules)} operations")
    
    def start(self):
        """Start the scheduler in a background thread"""
        if self.running:
            logger.warning("Scheduler is already running")
            return
        
        if not config.schedule_enabled:
            logger.info("Scheduling is disabled, not starting scheduler")
            return
        
        self.setup_cluster_schedules()
        
        if not self.schedules:
            logger.info("No scheduled jobs to run")
            return
        
        self.running = True
        self.scheduler_thread = threading.Thread(target=self._run_scheduler, daemon=True)
        self.scheduler_thread.start()
        logger.info("Scheduler started")
    
    def stop(self):
        """Stop the scheduler"""
        if not self.running:
            return
        
        self.running = False
        self.schedules.clear()
        logger.info("Scheduler stopped")
    
    def _run_scheduler(self):
        """Run the scheduler loop - check every minute"""
        logger.info("Scheduler thread started")
        while self.running:
            try:
                current_time = datetime.now()
                
                # Check all clusters
                for cluster in config.clusters:
                    cluster_id = cluster.cluster_id
                    
                    # Check if schedule is overridden for this cluster
                    if self.is_schedule_overridden(cluster_id, current_time):
                        logger.debug(f"Schedule is overridden for cluster {cluster.name}, skipping scheduled operations")
                        continue  # Skip to next cluster
                    
                    # Check hibernate first (higher priority)
                    hibernate_key = f"{cluster_id}_hibernate"
                    if hibernate_key in self.schedules:
                        if self.should_hibernate(cluster, current_time):
                            # Check if we already hibernated recently (avoid duplicates)
                            last_hibernate_key = f"{cluster_id}_hibernate_time"
                            last_hibernate = getattr(self, '_last_hibernate_times', {}).get(last_hibernate_key)
                            
                            # Only trigger if last hibernate was more than 5 minutes ago
                            if not last_hibernate or (current_time - last_hibernate).total_seconds() > 300:
                                # Initialize last_hibernate_times dict if needed
                                if not hasattr(self, '_last_hibernate_times'):
                                    self._last_hibernate_times = {}
                                
                                # Check cluster status before attempting hibernation
                                # If already Hibernation, skip to avoid unnecessary API calls and errors
                                try:
                                    cluster_status_data = cluster_manager.cloud_api.get_cluster_status(
                                        cluster.project_id, cluster.cluster_id
                                    )
                                    if cluster_status_data:
                                        current_status = cluster_status_data.get('status', {}).get('phase', 'Unknown')
                                        if current_status == 'Hibernation':
                                            logger.debug(f"Cluster {cluster.name} is already in Hibernation status, skipping scheduled hibernation")
                                            # Update last_hibernate_time to prevent repeated checks
                                            self._last_hibernate_times[last_hibernate_key] = current_time
                                            continue  # Skip to next cluster
                                except Exception as e:
                                    logger.warning(f"Failed to check cluster status before hibernation: {e}, proceeding anyway")
                                
                                logger.info(f"Scheduled hibernation triggered for cluster: {cluster.name}")
                                self._last_hibernate_times[last_hibernate_key] = current_time
                                # Run async function in new event loop
                                try:
                                    loop = asyncio.new_event_loop()
                                    asyncio.set_event_loop(loop)
                                    loop.run_until_complete(cluster_manager.hibernate_cluster(cluster))
                                    loop.close()
                                except Exception as e:
                                    logger.error(f"Error in scheduled hibernation: {e}", exc_info=True)
                    
                    # Check awake (only if hibernate_schedule exists)
                    # Logic: If time is NOT in hibernate_schedule, cluster should be awake
                    if cluster.hibernate_schedule:
                        if self.should_awake(cluster, current_time):
                            # Check if we already awoken recently (avoid duplicates)
                            last_awake_key = f"{cluster_id}_awake_time"
                            last_awake = getattr(self, '_last_awake_times', {}).get(last_awake_key)
                            
                            # Only trigger if last awake was more than 5 minutes ago
                            if not last_awake or (current_time - last_awake).total_seconds() > 300:
                                # Initialize last_awake_times dict if needed
                                if not hasattr(self, '_last_awake_times'):
                                    self._last_awake_times = {}
                                
                                # Check cluster status before attempting wake-up
                                # If already Available, skip to avoid unnecessary API calls and notifications
                                try:
                                    cluster_status_data = cluster_manager.cloud_api.get_cluster_status(
                                        cluster.project_id, cluster.cluster_id
                                    )
                                    if cluster_status_data:
                                        current_status = cluster_status_data.get('status', {}).get('phase', 'Unknown')
                                        if current_status == 'Available':
                                            logger.debug(f"Cluster {cluster.name} is already Available, skipping scheduled wake-up")
                                            # Update last_awake_time to prevent repeated checks
                                            self._last_awake_times[last_awake_key] = current_time
                                            continue  # Skip to next cluster
                                except Exception as e:
                                    logger.warning(f"Failed to check cluster status before wake-up: {e}, proceeding anyway")
                                
                                logger.info(f"Scheduled wake-up triggered for cluster: {cluster.name} (outside hibernate period)")
                                self._last_awake_times[last_awake_key] = current_time
                                # Run async function in new event loop
                                try:
                                    loop = asyncio.new_event_loop()
                                    asyncio.set_event_loop(loop)
                                    loop.run_until_complete(cluster_manager.awake_cluster(cluster))
                                    loop.close()
                                except Exception as e:
                                    logger.error(f"Error in scheduled wake-up: {e}", exc_info=True)
                
                # Check all ECS instances
                for instance in config.ecs_instances:
                    instance_id = instance.instance_id
                    
                    # Check stop first (higher priority)
                    stop_key = f"instance_{instance_id}_stop"
                    if stop_key in self.schedules:
                        if self.should_stop(instance, current_time):
                            # Check if we already stopped recently (avoid duplicates)
                            last_stop_key = f"{instance_id}_stop_time"
                            last_stop = getattr(self, '_last_stop_times', {}).get(last_stop_key)
                            
                            # Only trigger if last stop was more than 5 minutes ago
                            if not last_stop or (current_time - last_stop).total_seconds() > 300:
                                logger.info(f"Scheduled stop triggered for ECS instance: {instance.name}")
                                if not hasattr(self, '_last_stop_times'):
                                    self._last_stop_times = {}
                                self._last_stop_times[last_stop_key] = current_time
                                # Run async function in new event loop
                                try:
                                    loop = asyncio.new_event_loop()
                                    asyncio.set_event_loop(loop)
                                    loop.run_until_complete(ecs_instance_manager.stop_instance(instance))
                                    loop.close()
                                except Exception as e:
                                    logger.error(f"Error in scheduled instance stop: {e}", exc_info=True)
                    
                    # Check start (only if hibernate_schedule exists)
                    # Logic: If time is NOT in hibernate_schedule, instance should be running
                    if instance.hibernate_schedule:
                        if self.should_start(instance, current_time):
                            # Check if we already started recently (avoid duplicates)
                            last_start_key = f"{instance_id}_start_time"
                            last_start = getattr(self, '_last_start_times', {}).get(last_start_key)
                            
                            # Only trigger if last start was more than 5 minutes ago
                            if not last_start or (current_time - last_start).total_seconds() > 300:
                                logger.info(f"Scheduled start triggered for ECS instance: {instance.name} (outside hibernate period)")
                                if not hasattr(self, '_last_start_times'):
                                    self._last_start_times = {}
                                self._last_start_times[last_start_key] = current_time
                                # Run async function in new event loop
                                try:
                                    loop = asyncio.new_event_loop()
                                    asyncio.set_event_loop(loop)
                                    loop.run_until_complete(ecs_instance_manager.start_instance(instance))
                                    loop.close()
                                except Exception as e:
                                    logger.error(f"Error in scheduled instance start: {e}", exc_info=True)
                
            except Exception as e:
                logger.error(f"Error in scheduler loop: {e}", exc_info=True)
            
            time.sleep(self.check_interval)
        
        logger.info("Scheduler thread stopped")
    
    def get_scheduled_jobs(self) -> List[Dict]:
        """Get list of scheduled jobs"""
        jobs_info = []
        for key, schedules in self.schedules.items():
            if key.startswith('instance_'):
                # ECS instance schedule
                instance_id = key.replace('instance_', '').replace('_stop', '')
                instance = config.get_ecs_instance_by_id(instance_id)
                operation = 'stop'
                
                for i, schedule_rule in enumerate(schedules):
                    jobs_info.append({
                        'job_id': f"{key}_{i}",
                        'instance_id': instance_id,
                        'instance_name': instance.name if instance else 'Unknown',
                        'operation': operation,
                        'schedule': schedule_rule['original'],
                        'is_recurring': schedule_rule['is_recurring'],
                        'type': 'ecs_instance'
                    })
            else:
                # Cluster schedule
                cluster_id, operation = key.rsplit('_', 1)
                cluster = config.get_cluster_by_id(cluster_id)
                
                for i, schedule_rule in enumerate(schedules):
                    jobs_info.append({
                        'job_id': f"{key}_{i}",
                        'cluster_id': cluster_id,
                        'cluster_name': cluster.name if cluster else 'Unknown',
                        'operation': operation,
                        'schedule': schedule_rule['original'],
                        'is_recurring': schedule_rule['is_recurring'],
                        'type': 'cluster'
                    })
        
        return jobs_info
    
    def set_schedule_override(self, cluster_id: str, duration_hours: int, reason: str = "Manual override via API"):
        """Set schedule override for a cluster (ignore schedule for specified duration)"""
        with self.overrides_lock:
            override_until = datetime.now() + timedelta(hours=duration_hours)
            self.schedule_overrides[cluster_id] = {
                'until': override_until,
                'reason': reason,
                'set_at': datetime.now()
            }
            logger.info(f"Schedule override set for cluster {cluster_id} until {override_until.strftime('%Y-%m-%d %H:%M:%S')} (reason: {reason})")
    
    def clear_schedule_override(self, cluster_id: str):
        """Clear schedule override for a cluster"""
        with self.overrides_lock:
            if cluster_id in self.schedule_overrides:
                del self.schedule_overrides[cluster_id]
                logger.info(f"Schedule override cleared for cluster {cluster_id}")
                return True
            return False
    
    def is_schedule_overridden(self, cluster_id: str, current_time: datetime) -> bool:
        """Check if schedule is currently overridden for a cluster"""
        with self.overrides_lock:
            if cluster_id not in self.schedule_overrides:
                return False
            
            override = self.schedule_overrides[cluster_id]
            if current_time < override['until']:
                return True
            else:
                # Override expired, remove it
                del self.schedule_overrides[cluster_id]
                logger.info(f"Schedule override expired for cluster {cluster_id}")
                return False
    
    def get_schedule_override(self, cluster_id: str) -> Optional[Dict[str, Any]]:
        """Get current schedule override info for a cluster"""
        with self.overrides_lock:
            if cluster_id not in self.schedule_overrides:
                return None
            
            override = self.schedule_overrides[cluster_id]
            current_time = datetime.now()
            
            if current_time >= override['until']:
                # Override expired, remove it
                del self.schedule_overrides[cluster_id]
                return None
            
            return {
                'cluster_id': cluster_id,
                'until': override['until'].isoformat(),
                'reason': override['reason'],
                'set_at': override['set_at'].isoformat(),
                'remaining_seconds': int((override['until'] - current_time).total_seconds()),
                'remaining_hours': round((override['until'] - current_time).total_seconds() / 3600, 2)
            }
    
    def update_cluster_schedule(self, cluster_id: str, new_schedule: str) -> bool:
        """Update cluster schedule in runtime"""
        cluster = config.get_cluster_by_id(cluster_id)
        if not cluster:
            return False
        
        # Parse new schedule
        schedules = self.parse_schedules(new_schedule)
        if not schedules:
            return False
        
        # Update schedules
        hibernate_key = f"{cluster_id}_hibernate"
        self.schedules[hibernate_key] = schedules
        
        # Update cluster config (in-memory only, not persisted)
        cluster.hibernate_schedule = new_schedule
        
        logger.info(f"Schedule updated for cluster {cluster.name}: {new_schedule}")
        return True

# Global Schedule Manager instance
schedule_manager = ScheduleManager()
