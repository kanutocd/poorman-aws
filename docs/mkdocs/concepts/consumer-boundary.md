# Consumer boundary

`poorman-aws` owns reusable infrastructure, operational scripts, and reusable
workflow implementation. The consumer repository owns application code,
caller workflows, runtime configuration, and consumer-specific frontend
resources. This boundary keeps the reusable repository application-neutral.

The following values require an explicit consumer contract:

- application runtime environment variable names;
- SSM parameter paths;
- resource names and tags;
- Compose services and image names;
- immutable release manifest shape; and
- workflow paths, hostnames, and application commands.

Do not present application-specific defaults as public infrastructure interfaces
until they are parameterized and tested. When a value is consumer-owned, pass
it through the documented workflow input or wrapper configuration instead of
assuming a Compose service, directory layout, hostname, or command.
