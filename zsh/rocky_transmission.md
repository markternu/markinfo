# rocky_transmission

## zsh

```

sudo yum update -y && sudo yum install epel-release -y && yum install wget vim net-tools  zsh git screen zip aria2 jq unzip -y && echo "exec /bin/zsh" >> ~/.bashrc && sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)" -Y

```


## 替换本地zsh 历史

```

cd && sudo bash -c "curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/zsh/zsh_centos > .zsh_history"

```


# 7

```c

cd /  && mkdir wt && cd /wt && yum install epel-release -y && yum update -y && yum -y install transmission transmission-daemon

systemctl start transmission-daemon.service
systemctl stop transmission-daemon.service


vim /var/lib/transmission/.config/transmission-daemon/settings.json

```



```bash

1.  `"rpc-authentication-required":  true,` 
3.  `"rpc-password":  "mypassword",` 
4.  `"rpc-username":  "mysuperlogin",` 
5.  `"rpc-whitelist-enabled":  false,` 
6.  `"rpc-whitelist":  "0.0.0.0",`

"download-queue-enabled": true, 
    "download-queue-size": 5,


//上传速度限制，KB/s。对于ADSL，设为35已经很好了。tr可设置。
"speed-limit-up": 100,
/,启用上传速度限制，默认不启动，对于ADSL，还是根据需要开启吧。 tr可设置。
"speed-limit-up-enabled": true
```





