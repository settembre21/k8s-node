# Alicloud Providerの設定
provider "alicloud" {
  access_key = var.alicloud_access_key
  secret_key = var.alicloud_secret_key
  region     = var.alicloud_region
}

# sshキーペアの登録
resource "alicloud_key_pair" "deployer" {
  key_name   = "default"
  public_key = file(var.ssh_public_key_file)
}

# defaultのvpcを取得する
data "alicloud_vpcs" "default" {
  is_default = true
}

# セキュリティグループを取得する
data "alicloud_security_groups" "primary_sg" {
  vpc_id = data.alicloud_vpcs.default.ids[0]
}

# vswitch(subnet)を取得する
data "alicloud_vswitches" "default" {
  vpc_id = data.alicloud_vpcs.default.ids[0]
}

# インスタンスの作成とKubernetes環境の構築
resource "alicloud_instance" "instance" {
  availability_zone = data.alicloud_vswitches.default.vswitches[0].zone_id
  security_groups   = data.alicloud_security_groups.primary_sg.ids

  # vCPU x 2, 4GB Mem
  key_name                   = alicloud_key_pair.deployer.key_name
  instance_type              = "ecs.t5-lc1m2.large"
  system_disk_category       = "cloud_efficiency"
  image_id                   = "ubuntu_18_04_64_20G_alibase_20191112.vhd"
  instance_name              = "k8s-node"
  vswitch_id                 = data.alicloud_vswitches.default.vswitches[0].id
  internet_max_bandwidth_out = 10

  # dockerのcgroupdriverをsystemdへ切り替える設定ファイルを/tmpへ仮置
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = alicloud_instance.instance.public_ip
      private_key = file(var.ssh_private_key_file)
    }
    source      = "config/daemon.json"
    destination = "/tmp/daemon.json"
  }

  # Kubernetes環境をインストール
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = alicloud_instance.instance.public_ip
      private_key = file(var.ssh_private_key_file)
    }
    inline = [
      "apt-get update",
      "apt-get -y upgrade",
      # ここからdockerを入れるための準備
      "apt-get -y install apt-transport-https ca-certificates curl software-properties-common nfs-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "apt-key fingerprint 0EBFCD88",
      "add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      # ここからKubernetesを入れるための準備
      "echo \"deb https://apt.kubernetes.io/ kubernetes-xenial main\" > /etc/apt/sources.list.d/kubernetes.list",
      "apt-get update",
      # docker-ceとKubernetes関連をインストール
      "apt-get -y install docker-ce=5:18.09.9~3-0~ubuntu-bionic kubelet kubeadm kubectl",
      # docker-ceとKubernetes関連をホールド
      "apt-mark hold kubelet kubeadm kubectl docker-ce",
      # dockerのcgroupdriverをsystemdへ切り替える
      "cp /tmp/daemon.json /etc/docker/",
      "mkdir -p /etc/systemd/system/docker.service.d",
      "systemctl daemon-reload; systemctl restart docker",
    ]
  }
}

data "alicloud_instances" "instance" {
  ids = [alicloud_instance.instance.id]
}
