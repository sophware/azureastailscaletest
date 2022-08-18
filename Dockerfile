FROM golang:1.16.2-alpine3.13 as builder
WORKDIR /app
COPY . ./

# Install any required modules
RUN go mod download
# Copy over Go source code
COPY *.go ./
# Run the Go build and output binary under hello_go_http
RUN go build -o /hello_go_http

FROM alpine:latest as tailscale
WORKDIR /app
COPY . ./
#ENV TSFILE=tailscale_1.28.0_amd64.tgz
#RUN wget https://pkgs.tailscale.com/stable/${TSFILE} && \
#  tar xzf ${TSFILE} --strip-components=1
#COPY . ./
RUN echo http://dl-2.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories
RUN apk update && apk add tailscale && rm -rf /var/cache/apk/*
COPY . ./


FROM alpine:latest as ssh
WORKDIR /app
RUN apk update && apk add ca-certificates bash sudo && rm -rf /var/cache/apk/*

# Azure allows SSH access to the container. This isn't needed for Tailscale to
# operate, but is really useful for debugging the application.
RUN apk add openssh openssh-keygen && echo "root:Docker!" | chpasswd
RUN apk add netcat-openbsd
RUN mkdir -p /etc/ssh
COPY sshd_config /etc/ssh/

FROM alpine:latest
WORKDIR /app

COPY --from=builder /app/ssh_setup.sh /app/ssh_setup
RUN chmod +x /app/ssh_setup.sh && (sleep 1;/app/ssh_setup.sh 2>&1 > /dev/null)

# Copy binary to production image
COPY --from=builder /app/start.sh /app/start.sh
RUN chmod +x /app/start.sh
#COPY --from=tailscale /app/tailscaled /app/tailscaled
#COPY --from=tailscale /app/tailscale /app/tailscale

#RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale
RUN rc-update add tailscale

COPY --from=builder /hello_go_http /hello_go_http

EXPOSE 80 2222
# Run on container startup.
CMD ["/app/start.sh"]