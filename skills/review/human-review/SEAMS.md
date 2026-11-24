# Seam catalog

A **seam** is an implicit control-flow hop: control moves from one place to another, but
nothing at the call site names the destination. Go-to-definition stops at a seam, so a
reader following the flow loses it there. The Flow doc labels each seam on its diagram and
draws a close-up of each hop: sender, mechanism, receivers, and the wiring between them.

Each kind below gives its label for the Flow diagram (`<label>: <name>`), what to look
for, and its **risk flags**. The Flow doc adds a one-line risk flag under a seam only when
the change triggers it. A risk flag points the reader at something to check. It is never a
verdict.

The examples name common frameworks. Match the idea, not the spelling: a repo's own
framework has its own syntax for the same seam. A repo can add kinds in
`.reviews/seams.md`, in the same shape. Its entries win where they conflict with these.

## DI binding

Label `di`. An interface, token, or abstract type resolves to an implementation that
configuration chooses, not the call site.

- **Look for:** provider lists and container registrations (`providers: [...]`,
  `bind(...).to(...)`, `services.Add*`, `@Injectable`, `@Bean`), and constructors that take
  an interface.
- **Risk flags:** a binding changed with no caller changed; two bindings for one token; a
  scope change (singleton, request, transient).

## Event or message

Label `event`. One side emits by name and any number of listeners react.

- **Look for:** `emit(`, `publish(`, `dispatch(`, `@OnEvent`, `addEventListener`, `on(`,
  signal and hook registries, pub/sub topics.
- **Risk flags:** an event name changed on one side only; a payload shape changed; a new
  listener that throws or blocks the emitter; listener order that now matters.

## Middleware chain

Label `middleware`. Code runs before or after a handler because of where the handler is
registered, not because the handler calls it.

- **Look for:** guards, interceptors, pipes, filters, decorators on routes
  (`@UseGuards`, `@UseInterceptors`), `app.use(`, router-level middleware, Rails
  `before_action`, Django middleware lists, React Router loaders and actions.
- **Risk flags:** an auth or validation step added, removed, or reordered; a route moved
  out from under a guard; an error filter that now swallows an error.

## Queue or job

Label `job`. Work is enqueued now and runs later, in another process.

- **Look for:** `queue.add(`, `enqueue`, `perform_later`, `@Processor`, cron and scheduler
  registrations, outbox tables.
- **Risk flags:** a job payload changed while old jobs are still queued; retry or
  idempotency changed; work that used to be in a transaction now runs outside it.

## Workflow engine

Label `workflow`. A durable workflow starts, signals, or queries across a process
boundary, and replays its history.

- **Look for:** `workflow.start`, `executeChild`, `signal`, `query`, `proxyActivities`,
  Temporal, Step Functions, Airflow, and Cadence APIs.
- **Risk flags:** workflow code changed without versioning (`patched()` or the engine's
  equivalent); activity calls added, removed, or reordered; new non-deterministic calls in
  workflow code (time, randomness, I/O).

## Reflection or convention

Label `convention`. A name or a file location decides what runs: dynamic dispatch by
string, file-based routing, auto-discovery, metaprogramming.

- **Look for:** string-keyed handler maps, `getattr`, `send(`, `method_missing`,
  file-system routes, plugin auto-loading, glob imports.
- **Risk flags:** a file renamed or moved that changes what is discovered; a key string
  that no longer matches its handler.

## Lifecycle hook

Label `hook`. The framework calls code at a phase of its lifecycle.

- **Look for:** `onModuleInit`, `beforeEach`, ORM entity hooks (`@BeforeInsert`,
  `pre_save`), React effects, migrations that run on boot.
- **Risk flags:** a side effect added to a hook that runs more often than it seems; hook
  order changed; a migration that is not reversible or depends on data.

## Schema or contract

Label `contract`. Two sides agree on a shape that no type check spans: a DB schema and
its queries, an API and its clients, a serialized payload and its reader.

- **Look for:** migrations, OpenAPI and GraphQL schemas, protobufs, JSON column shapes,
  env vars and config keys read by name.
- **Risk flags:** a migration and the code that depends on it deploy in the wrong order; a
  field removed while a reader still uses it; a config key renamed on one side only.
