# Security policy

## Supported version

Security fixes are applied to the `main` branch. This repository contains examples and a local demo database; it is not a hosted service.

## Reporting a vulnerability

Email **zqmcomputing@gmail.com** with the subject `postgis-patterns security` if you find a vulnerability in the example code or workflow configuration. Please do not open a public issue for a sensitive report.

Include the affected file, the impact you observed, and reproduction steps when available.

## Local demo authentication

The Docker Compose demo uses PostgreSQL trust authentication inside a disposable container and binds its host port to `127.0.0.1` only. Do not expose that port, change the binding without adding real credentials, or reuse this configuration for a shared, hosted, or production PostgreSQL instance.
