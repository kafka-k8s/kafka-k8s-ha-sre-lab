#!/usr/bin/env python3
"""
Educational platform event consumer.

Reads learning events from a Kafka topic and prints them to stdout.
Exits after TIMEOUT_SECONDS of inactivity so local tests do not hang forever.

Environment variables:
  BOOTSTRAP_SERVERS   Kafka bootstrap server (default: localhost:9092)
  TOPIC               Kafka topic name (default: learning-events)
  CONSUMER_GROUP      Consumer group ID (default: sre-lab-consumers)
  TIMEOUT_SECONDS     Inactivity timeout before exit (default: 30)

Quick start:
  # In one terminal:
  make port-forward

  # In another terminal:
  make consume
  # or:
  TIMEOUT_SECONDS=60 python apps/consumer.py

Consumer groups:
  Using a stable consumer group ID allows Kafka to track read offsets.
  Run the consumer twice with the same CONSUMER_GROUP and it will resume
  where it left off. Change CONSUMER_GROUP to replay from the beginning.
"""

import json
import os

from kafka import KafkaConsumer
from kafka.errors import KafkaError

BOOTSTRAP_SERVERS = os.environ.get("BOOTSTRAP_SERVERS", "localhost:9092")
TOPIC = os.environ.get("TOPIC", "learning-events")
CONSUMER_GROUP = os.environ.get("CONSUMER_GROUP", "sre-lab-consumers")
TIMEOUT_SECONDS = int(os.environ.get("TIMEOUT_SECONDS", "30"))


def main() -> None:
    print("Consumer starting.")
    print(f"  Bootstrap:  {BOOTSTRAP_SERVERS}")
    print(f"  Topic:      {TOPIC}")
    print(f"  Group:      {CONSUMER_GROUP}")
    print(f"  Timeout:    {TIMEOUT_SECONDS}s of inactivity then exit")
    print(f"  Press Ctrl+C to exit early.")
    print()

    try:
        consumer = KafkaConsumer(
            TOPIC,
            bootstrap_servers=BOOTSTRAP_SERVERS,
            group_id=CONSUMER_GROUP,
            # Start from the earliest available offset when the group has no
            # committed offset yet (first run). Change to 'latest' to receive
            # only new messages produced after this consumer started.
            auto_offset_reset="earliest",
            enable_auto_commit=True,
            # consumer_timeout_ms causes the iterator to raise StopIteration
            # after this many milliseconds with no new messages, giving the
            # script a clean exit path instead of blocking forever.
            consumer_timeout_ms=TIMEOUT_SECONDS * 1000,
            value_deserializer=lambda v: json.loads(v.decode("utf-8")),
        )
    except KafkaError as err:
        print(f"[ERROR] Cannot connect to Kafka at {BOOTSTRAP_SERVERS}: {err}")
        print()
        print("Is port-forward running? Try: make port-forward")
        raise SystemExit(1)

    received = 0
    try:
        for message in consumer:
            received += 1
            print(
                f"[{received}] partition={message.partition} "
                f"offset={message.offset}  "
                f"{json.dumps(message.value)}"
            )
    except KeyboardInterrupt:
        print("\nInterrupted by user.")
    finally:
        consumer.close()

    print()
    print(f"Done. Consumed {received} messages from '{TOPIC}'.")


if __name__ == "__main__":
    main()
