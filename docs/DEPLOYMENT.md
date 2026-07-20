# Deploying To Render

Render is the first recommended hosting target for this project. In plain
language, Render connects to the GitHub repository, builds the existing
`Dockerfile`, starts the Rails app, gives it a public HTTPS URL, and redeploys
when changes are merged to the selected branch.

The initial deployment is intentionally small:

- one paid Render web service,
- one persistent disk mounted at `/rails/storage`,
- SQLite for the application and Rails Solid databases,
- Active Storage files on the same disk, and
- Solid Queue running inside the web process.

This layout is suitable for a personal-project MVP. It is not the recommended
shape for a horizontally scaled or high-availability production system.

## Before You Start

You need:

- this repository pushed to GitHub,
- a [Render account](https://dashboard.render.com/),
- the value from `config/master.key`, and
- an API key for the selected LLM provider, unless using the fake provider.

Do not commit `config/master.key`, `.env`, or provider API keys.

This SQLite deployment requires a **paid Render web service** because free web
services cannot attach persistent disks. Without a disk, the databases and
uploads are lost whenever the service restarts or redeploys.

## Create The Web Service

1. In Render, select **New > Web Service** and connect the GitHub repository.
2. Select the branch to deploy, normally `main`.
3. Set **Language** to **Docker**. The repository's root `Dockerfile` is used.
4. Choose a paid instance type that supports a persistent disk.
5. Leave **Docker Command** blank so Render uses the `CMD` from the Dockerfile.
6. Set the health check path to `/up`.
7. Add a persistent disk and set its mount path to `/rails/storage`.
8. Add the environment variables listed below.
9. Deploy the service.

The container binds Rails to Render's `PORT` automatically. The Docker
entrypoint runs `bin/rails db:prepare` before starting Rails, which creates or
migrates the SQLite databases on the mounted disk.

Do not configure `bin/rails db:prepare` as a Render pre-deploy command. Render
runs pre-deploy commands on separate compute that cannot access the persistent
disk.

## Environment Variables

Add variables from the Render service's **Environment** page. Render stores
these values outside the repository.

| Variable | Value | Required |
| --- | --- | --- |
| `RAILS_MASTER_KEY` | Contents of local `config/master.key` | Yes |
| `SOLID_QUEUE_IN_PUMA` | `true` | Yes |
| `WEB_CONCURRENCY` | `1` | Yes for this SQLite layout |
| `SUPPORT_BOT_PROVIDER` | `fake`, `fireworks`, `openai`, or `openai_compatible` | Yes |
| `FIREWORKS_API_KEY` | Fireworks API key | When using `fireworks` |
| `FIREWORKS_MODEL` | Optional Fireworks model override | No |
| `OPENAI_API_KEY` | OpenAI API key | When using `openai` |
| `OPENAI_BASE_URL` | Optional OpenAI-compatible endpoint override | No |
| `LLM_API_KEY` | Provider API key | When using `openai_compatible` |
| `LLM_BASE_URL` | Provider chat-completions base URL | When using `openai_compatible` |
| `LLM_MODEL` | Provider model identifier | When using `openai_compatible` |
| `BOT_CONFIDENCE_THRESHOLD` | Confidence percentage, default `70` | No |
| `RAILS_LOG_LEVEL` | `info` is the application default | No |

Use `SUPPORT_BOT_PROVIDER=fake` for a no-cost smoke test. Use a real provider
only after its corresponding key is configured.

`RAILS_ENV` is already set to `production` in the Docker image. Render also
provides `PORT`, so neither variable needs to be added manually.

## Database Setup

Production uses four SQLite files under `storage/`:

- `production.sqlite3` for application data,
- `production_cache.sqlite3` for Solid Cache,
- `production_queue.sqlite3` for Solid Queue, and
- `production_cable.sqlite3` for Solid Cable.

Mounting the disk at `/rails/storage` preserves all four files across restarts
and deploys. The Docker entrypoint runs `db:prepare` each time the service
starts, so a separate migration command is not required for this layout.

After the first deploy, use the Render Shell to create an operator account if
one does not already exist:

```sh
bin/rails runner 'OperatorUser.create!(email: "operator@example.test", password: "replace-this-password")'
```

Use a unique email and a strong password. The seeded development password is
not appropriate for a public deployment.

## Background Jobs

Bot responses and knowledge ingestion run through Solid Queue. Set
`SOLID_QUEUE_IN_PUMA=true` so the Rails web service starts the Solid Queue
supervisor inside Puma.

Do not add a separate Render background worker while the app uses this SQLite
layout. A Render disk belongs to one service and cannot be shared with another
service, so a separate worker would not see the web service's queue database.

When the project moves to a shared database such as Postgres, the worker can be
split into its own Render background worker and started with:

```sh
bin/jobs
```

## File Storage

Production Active Storage currently uses the local `storage/` directory. The
same `/rails/storage` disk therefore preserves customer uploads along with the
SQLite databases.

This is acceptable for the MVP but couples uploads to one service instance.
Before scaling the app, move uploads to object storage such as Amazon S3 and
move the databases to a shared managed database.

Monitor disk usage and keep independent database backups. Render disk snapshots
are useful for whole-disk recovery, but restoring a snapshot also rolls back
uploads and every SQLite database to the same earlier point in time.

## Verify The Deployment

1. Confirm the deploy log shows `db:prepare` completing and Rails starting.
2. Open `https://YOUR-SERVICE.onrender.com/up` and confirm it returns a healthy response.
3. Create a customer conversation and send a message.
4. Confirm a bot response appears without refreshing.
5. Open the operator view and test a response that requires review.
6. Restart the service and confirm conversations and uploaded files remain.

## Known Limitations

- A persistent disk is available only on paid Render services.
- The disk can attach to only one service instance, so this deployment cannot
  scale horizontally.
- Disk-backed services have a short interruption during deploys instead of
  zero-downtime instance replacement.
- Solid Queue shares the web process, so heavy jobs can compete with customer
  requests for CPU and memory.
- Local Active Storage does not provide object-storage durability, a CDN, or
  independent upload scaling.
- SQLite is appropriate for this MVP, not a multi-instance or high-traffic
  production system.
- Operator authentication is intentionally basic and needs production-grade
  access controls before handling real customer data.
- LLM availability, rate limits, latency, and cost depend on the configured
  provider.

## Upgrade Path

The first infrastructure upgrade should be moving the application, queue,
cache, and cable data to shared managed services. After that:

1. run Solid Queue in a separate Render background worker,
2. move Active Storage to object storage,
3. allow multiple web instances, and
4. add production monitoring, backup, and access-control practices.

## Render References

- [Docker services](https://render.com/docs/docker)
- [Persistent disks](https://render.com/docs/disks)
- [Environment variables and secrets](https://render.com/docs/configure-environment-variables)
- [Health checks](https://render.com/docs/health-checks)
- [Background workers](https://render.com/docs/background-workers)
- [Free service limitations](https://render.com/docs/free)
