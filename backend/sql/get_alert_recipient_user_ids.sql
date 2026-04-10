create or replace function public.get_alert_recipient_user_ids(
  p_alert_id bigint
)
returns table (
  user_id bigint,
  distance_m double precision
)
language sql
stable
as $$
  select
    u.id as user_id,
    st_distance(u.location, a.location) as distance_m
  from public.alerts a
  join public.users u on u.id <> a.user_id
  where a.id = p_alert_id
    and a.location is not null
    and u.location is not null
    and st_dwithin(
      u.location,
      a.location,
      greatest(coalesce(u.preferred_radius_m, 0), 0)
        + greatest(coalesce(a.radius_m, 0), 0)
    );
$$;