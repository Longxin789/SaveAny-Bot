# 第一阶段：使用与目标平台一致的构建环境
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

ARG VERSION="dev"
ARG GitCommit="Unknown"
ARG BuildTime="Unknown"
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /app

# 启用Go模块缓存
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# 复制源码并构建
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=$(case ${TARGETARCH} in "arm") echo "arm" ;; *) echo ${TARGETARCH} ;; esac) \
    GOARM=$(case ${TARGETVARIANT} in "v7") echo "7" ;; *) echo "" ;; esac) \
    go build -trimpath -v \  # 添加-v查看详细进度
    -ldflags "-s -w \
    -X github.com/krau/SaveAny-Bot/common.Version=${VERSION} \
    -X github.com/krau/SaveAny-Bot/common.GitCommit=${GitCommit} \
    -X github.com/krau/SaveAny-Bot/common.BuildTime=${BuildTime}" \
    -o saveany-bot .

# 第二阶段：使用轻量级基础镜像
FROM alpine:latest AS runtime

# 安装最小依赖
RUN apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

WORKDIR /app

# 从构建阶段复制二进制文件和脚本
COPY --from=builder /app/saveany-bot .
COPY --from=builder /app/entrypoint.sh .

# 设置执行权限
RUN chmod +x /app/saveany-bot && \
    chmod +x /app/entrypoint.sh

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
