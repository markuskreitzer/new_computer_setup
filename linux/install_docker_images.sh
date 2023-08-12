function install_yq {
  echo "Install jq, xq, and yq"
  sudo docker pull linuxserver/yq
  sudo $CURL_CERT_IGNORE curl -L --fail https://raw.githubusercontent.com/linuxserver/docker-yq/master/run-yq.sh -o /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq
  sudo $CURL_CERT_IGNORE curl -L --fail https://raw.githubusercontent.com/linuxserver/docker-yq/master/run-jq.sh -o /usr/local/bin/jq && sudo chmod +x /usr/local/bin/jq
  sudo $CURL_CERT_IGNORE curl -L --fail https://raw.githubusercontent.com/linuxserver/docker-yq/master/run-xq.sh -o /usr/local/bin/xq && sudo chmod +x /usr/local/bin/xq
}

install_yq
