#!/usr/bin/env python3
"""
Educational platform event producer.

Sends sample learning events to a Kafka topic using acks=all for durability.
The producer connects to a local Kafka bootstrap server (via port-forward) and
sends JSON-encoded events representing student activity on an e-learning platform.

Environment variables:
  BOOTSTRAP_SERVERS   Kafka bootstrap server (default: localhost:9092)
  TOPIC               Kafka topic name (default: learning-events)
  MESSAGE_COUNT       Number of messages to send (default: 10)
  DELAY_SECONDS       Seconds between messages (default: 1.0)

Quick start:
  # In one terminal:
  make port-forward

  # In another terminal:
  make produce
  # or:
  MESSAGE_COUNT=50 DELAY_SECONDS=0.5 python apps/producer.py
"""

import json
import os
import random
import time
from datetime import datetime, timezone

from kafka import KafkaProducer
from kafka.errors import KafkaError

BOOTSTRAP_SERVERS = os.environ.get("BOOTSTRAP_SERVERS", "localhost:9092")
TOPIC = os.environ.get("TOPIC", "learning-events")
MESSAGE_COUNT = int(os.environ.get("MESSAGE_COUNT", "10"))
DELAY_SECONDS = float(os.environ.get("DELAY_SECONDS", "1.0"))

COURSES = [
    "english-a2",
    "math-b1",
    "history-c1",
    "science-a1",
    "coding-101",
]

EVENT_TYPES = [
    "lesson_completed",
    "quiz_submitted",
    "video_watched",
    "assignment_submitted",
]


def build_event(index: int) -> dict:
    return {
        "student_id": f"u-{1000 + (index % 20)}",
        "course": random.choice(COURSES),
        "event": random.choice(EVENT_TYPES),
        "score": random.randint(60, 100),
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }


def main() -> None:
    print("Producer starting.")
    print(f"  Bootstrap: {BOOTSTRAP_SERVERS}")
    print(f"  Topic:     {TOPIC}")
    print(f"  Messages:  {MESSAGE_COUNT}")
    print()

    try:
        producer = KafkaProducer(
            bootstrap_servers=BOOTSTRAP_SERVERS,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            # acks=all requires all in-sync replicas to acknowledge the write.
            # Combined with min.insync.replicas=2 on the topic, this ensures
            # durability even if one broker goes down after the write.
            acks="all",
            retries=5,
            retry_backoff_ms=500,
            request_timeout_ms=15000,
        )
    except KafkaError as err:
        print(f"[ERROR] Cannot connect to Kafka at {BOOTSTRAP_SERVERS}: {err}")
        print()
        print("Is port-forward running? Try: make port-forward")
        raise SystemExit(1)

    sent = 0
    for i in range(MESSAGE_COUNT):
        event = build_event(i)
        try:
            future = producer.send(TOPIC, value=event)
            meta = future.get(timeout=15)
            print(
                f"[{i + 1}/{MESSAGE_COUNT}] OK  "
                f"partition={meta.partition} offset={meta.offset}  "
                f"{json.dumps(event)}"
            )
            sent += 1
        except KafkaError as err:
            print(f"[{i + 1}/{MESSAGE_COUNT}] ERROR: {err}")

        if i < MESSAGE_COUNT - 1:
            time.sleep(DELAY_SECONDS)

    producer.flush()
    producer.close()
    print()
    print(f"Done. Sent {sent}/{MESSAGE_COUNT} messages to '{TOPIC}'.")


if __name__ == "__main__":
    main()
