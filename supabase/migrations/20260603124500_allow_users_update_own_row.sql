create policy "Enable update for users on own profile"
on "public"."users"
as permissive
for update
to authenticated
using ((auth.uid() = auth_id))
with check ((auth.uid() = auth_id));
