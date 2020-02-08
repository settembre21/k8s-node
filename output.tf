# 構築したインスタンスの情報を表示する
output "instance" {
  value = {
    instance = data.alicloud_instances.instance
  }
}
