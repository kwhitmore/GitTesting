--liquibase formatted sql

--changeset nvoxland:1
create table test1 (
  id int not null primary key,
  name varchar(255)
);

--rollback
delete from test1;

--test comment