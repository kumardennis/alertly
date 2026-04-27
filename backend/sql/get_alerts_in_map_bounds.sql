create or replace function public.get_alerts_in_map_bounds(
  p_south_lat double precision,
  p_west_lng double precision,
  p_north_lat double precision,
  p_east_lng double precision,
  p_limit integer default 200
)
returns table (
  alert_id bigint,
  title text,
  body text,
  category text,
  status text,
  flagged boolean,
  user_id bigint,
  tier integer,
  radius_m integer,
  created_at timestamptz,
  published_at timestamptz,
  latitude double precision,
  longitude double precision
)
language sql
stable
as $$
  with normalized_bounds as (
    select
      least(p_south_lat, p_north_lat) as south_lat,
      greatest(p_south_lat, p_north_lat) as north_lat,
      p_west_lng as west_lng,
      p_east_lng as east_lng,
      greatest(coalesce(p_limit, 200), 1) as result_limit
  )
  select
    a.id as alert_id,
    a.title,
    a.body,
    a.category,
    a.status,
    a.flagged,
    a.user_id,
    a.tier,
    a.radius_m,
    a.created_at,
    a.published_at,
    st_y(a.location::geometry) as latitude,
    st_x(a.location::geometry) as longitude
  from public.alerts a
  cross join normalized_bounds b
  where a.location is not null
    and a.status = 'published'
    and st_y(a.location::geometry) between b.south_lat and b.north_lat
    and (
      (b.west_lng <= b.east_lng and st_x(a.location::geometry) between b.west_lng and b.east_lng)
      or
      (b.west_lng > b.east_lng and (
        st_x(a.location::geometry) >= b.west_lng
        or st_x(a.location::geometry) <= b.east_lng
      ))
    )
  order by coalesce(a.published_at, a.created_at) desc
  limit (select result_limit from normalized_bounds);
$$;
