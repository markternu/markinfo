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

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/transmission/ubuntutr.sh)"

```


# 4all脚本就直接将整个shell 脚本git clone


```

git clone https://github.com/markternu/markinfo.git

```


## 或者

```

wget https://raw.githubusercontent.com/markternu/markinfo/master/newshell/all.sh)"

```




# 5安装Trojan




```
sudo apt update

sudo apt install wget vim net-tools jq -y
```


```

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/2n/init/ubuntu_utf8_set.sh)"

```


```

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/2n/init/ubuntuTrojanInstall.sh)"

```



# 6处理视频文件有两个版本的脚本


## 0老脚本使用的是固定字节的末端追加
###  100个字节的标志位+1000个字节的内容

### 一键调用
```

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/mvvideofile/all0.sh)"

```

## 1新的脚本就是采用 V+L+T结构进行末端追加

### 一键调用
```

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/mvvideofile/all1.sh)"

```

