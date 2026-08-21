-- Outbox table schema

create table if not exists outbox_messages
(
    id                  uuid,
    status              varchar(55)               not null,
    created_at          timestamp with time zone  not null default now(),
    updated_at          timestamp with time zone  not null default now(),
    headers             jsonb,
    key                 text,
    value               text,
    source              varchar(255)              not null,
    version             int                       not null,
    count_retry         int                       not null default 0,
    PRIMARY KEY         (id, created_at)
)   PARTITION BY RANGE (created_at);

create table if not exists users
(
    id                  uuid PRIMARY KEY,
    name                varchar(55)               not null,
    email               varchar(55)               not null
);