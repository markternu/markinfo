# Rocky_linux 安装 oh my zsh


```




# 1. 更新系统包
sudo dnf update -y

# 2. 安装必要依赖
sudo dnf install -y zsh git curl

# 3. 安装 Oh My Zsh（推荐使用 curl）
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"




sudo dnf update -y && sudo dnf install -y zsh git curl && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"










```


## 替换本地zsh 历史 centos

```

cd && sudo bash -c "curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/zsh/zsh_centos > .zsh_history"

```




```



# 1. 安装 util-linux-user 包（包含 chsh 命令）
sudo dnf install -y util-linux-user

# 2. 设置 Zsh 为默认 Shell
chsh -s $(which zsh)

# 3. 或者直接编辑 /etc/passwd 文件（替代方法）
# 找到当前用户行，将末尾的 /bin/bash 改为 /usr/bin/zsh
sudo vim /etc/passwd

# 4. 验证 zsh 路径
which zsh

# 5. 重新登录后验证
echo $SHELL

# 6. 手动启动 zsh（临时使用）
zsh

```