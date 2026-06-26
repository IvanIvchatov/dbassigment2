--not optimized example

explain analyze
select
  (
    select concat(e.first_name, ' ', e.last_name, ': ', s1.cnt)
    from (
      select t.employee_id, e2.first_name, e2.last_name, count(*) as cnt
      from transactions t
      join accounts a on t.account_id = a.account_id
      join employees e2 on t.employee_id = e2.employee_id
      where t.transaction_type = 'DEPOSIT'
        and a.account_type = 'SAVINGS'
        and t.transaction_date > '2023-06-01'
      group by t.employee_id, e2.first_name, e2.last_name
    ) s1
    join employees e on s1.employee_id = e.employee_id
    where s1.cnt = (
        select min(cnt) from (
          select count(*) as cnt
          from transactions t
          join accounts a on t.account_id = a.account_id
          join employees e2 on t.employee_id = e2.employee_id
          where t.transaction_type = 'DEPOSIT'
            and a.account_type = 'SAVINGS'
            and t.transaction_date > '2023-06-01'
          group by t.employee_id
        ) sub
    )
    limit 1
  ) as min_deposit_employee,
  (
    select concat(e.first_name, ' ', e.last_name, ': ', s2.cnt)
    from (
      select t.employee_id, e2.first_name, e2.last_name, count(*) as cnt
      from transactions t
      join accounts a on t.account_id = a.account_id
      join employees e2 on t.employee_id = e2.employee_id
      where t.transaction_type = 'DEPOSIT'
        and a.account_type = 'SAVINGS'
        and t.transaction_date > '2023-06-01'
      group by t.employee_id, e2.first_name, e2.last_name
    ) s2
    join employees e on s2.employee_id = e.employee_id
    where s2.cnt = (
        select max(cnt) from (
          select count(*) as cnt
          from transactions t
          join accounts a on t.account_id = a.account_id
          join employees e2 on t.employee_id = e2.employee_id
          where t.transaction_type = 'DEPOSIT'
            and a.account_type = 'SAVINGS'
            and t.transaction_date > '2023-06-01'
          group by t.employee_id
        ) sub
    )
    limit 1
  ) as max_deposit_employee;

--___________________________________________________
create index if not exists idx_transactions_type_date
    on transactions(transaction_type, transaction_date);

create index if not exists idx_transactions_account_id
    on transactions(account_id);

create index if not exists idx_transactions_employee_id
    on transactions(employee_id);

create index if not exists idx_accounts_type
    on accounts(account_type);

--_________________________________________________________
--optimized example
explain analyze
with filtered_tx as (
  select t.employee_id, e.first_name, e.last_name
  from transactions t
  join accounts a on t.account_id = a.account_id
  join employees e on t.employee_id = e.employee_id
  where t.transaction_type = 'DEPOSIT'
    and a.account_type = 'SAVINGS'
    and t.transaction_date > '2023-06-01'
),
cnt_employees as (
  select employee_id, first_name, last_name, count(*) as cnt
  from filtered_tx
  group by employee_id, first_name, last_name
),
ranked as (
  select first_name, last_name, cnt,
    row_number() over (order by cnt asc, employee_id asc) as min_rn,
    row_number() over (order by cnt desc, employee_id asc) as max_rn
  from cnt_employees
)
select
  max(concat(first_name, ' ', last_name, ': ', cnt)) filter (where min_rn = 1) as min_deposit_employee,
  max(concat(first_name, ' ', last_name, ': ', cnt)) filter (where max_rn = 1) as max_deposit_employee
from ranked;