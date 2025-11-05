.PHONY: build build-base1 build-base2 build-base2-latest rebuild-base2 run stop restart clean ssh ssh-root logs rebuild help

# 配置变量
IMAGE_NAME = oh-my-arch
CONTAINER_NAME = oh-my-arch-container
SSH_PORT = 2222

# Dockerfile 列表（按顺序）
DOCKERFILES = Dockerfile.base1 Dockerfile.base2

# 默认目标
help:
	@echo "可用命令:"
	@echo "  make build       - 链式构建所有 Docker 镜像"
	@echo "  make build-base1 - 仅构建 base1"
	@echo "  make build-base2 - 仅构建 base2（需要先构建 base1）"
	@echo "  make build-base2-latest - 构建 base2 并标记为 latest（需要先构建 base1）"
	@echo "  make rebuild-base2 - 停止容器，重建 base2 latest，并重新启动"
	@echo "  make run         - 启动容器（默认启用 GPU 支持）"
	@echo "  make stop        - 停止容器"
	@echo "  make restart     - 重启容器"
	@echo "  make rebuild     - 重新构建并启动容器"
	@echo "  make ssh         - SSH 连接到容器 (用户: yun)"
	@echo "  make ssh-root    - SSH 连接到容器 (用户: root)"
	@echo "  make logs        - 查看容器日志"
	@echo "  make clean       - 停止并删除容器和镜像"

# 构建 base1
build-base1:
	@echo "构建 base1..."
	docker build -f Dockerfile.base1 -t $(IMAGE_NAME):base1 .

# 构建 base2（基于 base1）
build-base2: build-base1
	@echo "构建 base2..."
	docker build -f Dockerfile.base2 -t $(IMAGE_NAME):base2 .

# 构建 base2 并直接标记为 latest（基于已存在的 base1 镜像）
build-base2-latest:
	@echo "构建 base2 并标记为 latest..."
	@if ! docker image inspect $(IMAGE_NAME):base1 >/dev/null 2>&1; then \
		echo "未找到 $(IMAGE_NAME):base1 镜像，请先执行 make build-base1"; \
		exit 1; \
	fi
	docker build -f Dockerfile.base2 -t $(IMAGE_NAME):latest .

# 停止容器并重建 base2 latest，然后重新启动
rebuild-base2: stop build-base2-latest run

# 链式构建所有镜像，最后一个标记为 latest
build: build-base1 build-base2
	@echo "所有镜像构建完成，标记最终镜像为 latest..."
	docker tag $(IMAGE_NAME):base2 $(IMAGE_NAME):latest

# 启动容器（默认启用 GPU 支持）
run:
	docker run -d \
		--name $(CONTAINER_NAME) \
		--hostname yun \
		--runtime=nvidia \
		-e NVIDIA_VISIBLE_DEVICES=all \
		-e NVIDIA_DRIVER_CAPABILITIES=all \
		-p $(SSH_PORT):22 \
		$(IMAGE_NAME)
	@echo "容器已启动（GPU 已启用），SSH 端口映射到 $(SSH_PORT)"

# 停止容器
stop:
	docker stop $(CONTAINER_NAME) || true
	docker rm $(CONTAINER_NAME) || true

# 重启容器
restart: stop run

# 重新构建并启动
rebuild: stop build run

# SSH 连接到容器 (yun 用户，禁用指纹验证)
ssh:
	@ssh -p $(SSH_PORT) yun@localhost

# SSH 连接到容器 (root 用户，禁用指纹验证)
ssh-root:
	@ssh -p $(SSH_PORT) root@localhost

# 查看容器日志
logs:
	docker logs -f $(CONTAINER_NAME)

# 清理所有资源
clean: stop
	docker rmi $(IMAGE_NAME) || true
	@echo "已清理所有资源"
