# 1安装zsh
## 一条命令

```


sudo apt update -y && sudo apt install -y zsh git net-tools curl && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"


```


## 替换本地zsh 历史 zsh_ubuntu

```

cd && sudo bash -c "curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/zsh/zshubuntu > .zsh_history"

```

# 2安装nginx
# 安装必要的软件包
apt-get update
apt-get install -y nginx 




# 3 安装transmission Ubuntu

```

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/transmission/ubuntu_transmission.sh)"

```


# 4all脚本就直接将整个shell 脚本git clone


```

git clone https://github.com/markternu/markinfo.git

```


## 或者

```

wget https://raw.githubusercontent.com/markternu/markinfo/master/newshell/all.sh)"

```
