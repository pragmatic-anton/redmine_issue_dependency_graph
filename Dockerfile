FROM redmine:4

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends graphviz; \
	rm -rf /var/lib/apt/lists/*
