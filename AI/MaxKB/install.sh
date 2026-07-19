#!/usr/bin/env bash

# https://community.fit2cloud.com/#/products/maxkb/getstarted
# 1、先确认安装了docker，通过docker安装maxkb
# 要指定版本
docker pull registry.fit2cloud.com/maxkb/maxkb


# 2、启动
mkdir -p ~/.maxkb ~/.python-packages
chmod -R 755 ~/.maxkb ~/.python-packages
docker run -d --name=maxkb --restart=always -p 8080:8080 -v ~/.maxkb:/var/lib/postgresql/data -v ~/.python-packages:/opt/maxkb/app/sandbox/python-packages registry.fit2cloud.com/maxkb/maxkb

# 设置 OLLAMA_HOST 的方法
# 方法1、容器启动时加参数
-e OLLAMA_HOST=http://localhost:11434

# 方法2、在已运行的容器中设置环境变量，不生效
#docker exec -it maxkb bash
#echo "OLLAMA_HOST=http://localhost:11434" >> /etc/environment
#docker restart maxkb

# 在容器中验证
docker exec -it maxkb bash
echo $OLLAMA_HOST


# 3、ollama安装
curl -fsSL https://ollama.com/install.sh | sh
