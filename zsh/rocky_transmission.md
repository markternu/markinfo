# rocky_transmission

## zsh

```

sudo yum update -y && sudo yum install epel-release -y && yum install wget vim net-tools  zsh git screen zip aria2 jq unzip -y && echo "exec /bin/zsh" >> ~/.bashrc && sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)" -Y

```


## 替换本地zsh 历史

```

cd && sudo bash -c "curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/zsh/zsh_centos > .zsh_history"

```



