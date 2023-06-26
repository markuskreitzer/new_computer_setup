# Gitlab Runner Setup
Run:

```
docker run --rm -it -v gitlab-runner-config:/etc/gitlab-runner gitlab/gitlab-runner:latest register
```

While the above command is running:
docker attach -it $(docker ps | awk '/gitlab-runner/{print $1}') bash

In the container, run:

```
openssl s_client -showcerts -connect ${CI_REGISTRY}:443 -servername ${CI_REGISTRY} < /dev/null 2>/dev/null | openssl x509 -outform PEM > /etc/gitlab-runner/certs/${CI_REGISTRY}.crt
```

Continue on with registration.

One liner that I need to get working.
```
docker run --rm -v /srv/gitlab-runner/config:/etc/gitlab-runner gitlab/gitlab-runner register \
  --non-interactive \
  --executor "docker" \
  --docker-image alpine:latest \
  --url "https://gitlab.com/" \
  --registration-token "PROJECT_REGISTRATION_TOKEN" \
  --description "docker-runner" \
  --maintenance-note "Free-form maintainer notes about this runner" \
  --tag-list "docker,aws" \
  --run-untagged="true" \
  --locked="false" \
  --access-level="not_protected"

```