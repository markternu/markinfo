#!/bin/bash

# Step 1: Set language and encoding environment variables
echo "export LANG=en_US.UTF-8" >> ~/.bashrc
echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc
source ~/.bashrc

# Step 2: Set Vim encoding settings
echo "set encoding=utf-8" >> ~/.vimrc
echo "set fileencoding=utf-8" >> ~/.vimrc
echo "set fileencodings=utf-8" >> ~/.vimrc
source ~/.bashrc

