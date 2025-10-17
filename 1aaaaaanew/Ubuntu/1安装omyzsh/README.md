# 安装 oh my zsh


# 1. 更新系统包


```


sudo apt update -y


```



# 2. 安装必要依赖


```


sudo apt install -y zsh git curl


```



# 3. 安装 Oh My Zsh（推荐使用 curl）

```


sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

```




```


sudo apt update -y && sudo apt install -y zsh git curl && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"


```









## 替换本地zsh 历史 zsh_ubuntu

```

cd && sudo bash -c "curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/zsh/zshubuntu > .zsh_history"

```







# 完整版和手动选择

```

# 1. 更新系统包
sudo apt update

# 2. 安装必要依赖
sudo apt install -y zsh git curl

# 3. 安装 Oh My Zsh（推荐使用 curl）
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# 或者使用 wget
# sh -c "$(wget https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"

# 4. 设置 Zsh 为默认 Shell
chsh -s $(which zsh)

# 5. 重新加载配置
source ~/.zshrc

# 验证安装 - 检查当前使用的 Shell
echo $SHELL


```








```





```