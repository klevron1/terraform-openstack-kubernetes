provider "openstack" {}

variable "private_key" {
  default = "/root/.ssh/id_rsa-kubernetes_the_hard_way"
}

variable "public_key" {
  default = "/root/.ssh/id_rsa-kubernetes_the_hard_way.pub"
}

variable "ssh_user" {
  default = "ubuntu"
}

resource "null_resource" "generate-sshkey" {
    provisioner "local-exec" {
        command = "yes y | ssh-keygen -b 4096 -t rsa -C 'kubernetes_the_hard_way' -N '' -f ${var.private_key}"
    }
}

resource "openstack_compute_keypair_v2" "kubernetes-the-hard-way-keypair" {
  name       = "kubernetes-the-hard-way-keypair"
  public_key = "${file(var.public_key)}"
  depends_on = ["null_resource.generate-sshkey"]
}

resource "openstack_networking_network_v2" "kubernetes-the-hard-way" {
  name           = "kubernetes-the-hard-way"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "kubernetes" {
  name       = "kubernetes"
  network_id = "${openstack_networking_network_v2.kubernetes-the-hard-way.id}"
  cidr       = "10.240.0.0/24"
  ip_version = 4
}

resource "openstack_compute_secgroup_v2" "kubernetes-the-hard-way-allow-external" {
  name        = "kubernetes-the-hard-way-allow-external"
  description = "permitted inbound external traffic"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 6443
    to_port     = 6443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }

}

data "openstack_images_image_v2" "ubuntu_18_04" {
  name = "Ubuntu 18.04"
  most_recent = true
}

data "openstack_compute_flavor_v2" "s1-2" {
  name = "s1-4"
}

resource "openstack_compute_instance_v2" "controllers" {
  count           = 3
  name            = "controller-${count.index}"
  image_id        = "${data.openstack_images_image_v2.ubuntu_18_04.id}"
  flavor_id       = "${data.openstack_compute_flavor_v2.s1-2.id}"
  key_pair        = "${openstack_compute_keypair_v2.kubernetes-the-hard-way-keypair.name}"
  security_groups = ["${openstack_compute_secgroup_v2.kubernetes-the-hard-way-allow-external.name}"]

  network {
    name = "Ext-Net",
  }

  network {
    name = "${openstack_networking_network_v2.kubernetes-the-hard-way.name}"
    fixed_ip_v4 = "10.240.0.1${count.index}"
  }

  metadata {
    kubernetes-the-hard-way = "controller"
  }

  provisioner "file" {
    source      = "files/controller-${count.index}_01-ens4.yaml"
    destination = "/tmp/01-ens4.yaml"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

  provisioner "file" {
    source      = "${var.public_key}"
    destination = "/tmp/authorized_keys"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/01-ens4.yaml /etc/netplan/01-ens4.yaml",
      "sudo netplan apply",
      "sudo mv /tmp/authorized_keys /root/.ssh/authorized_keys",
      "sudo chmod 600 /root/.ssh/authorized_keys",
    ]
    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

}

resource "openstack_compute_instance_v2" "workers" {
  count           = 3
  name            = "worker-${count.index}"
  image_id        = "${data.openstack_images_image_v2.ubuntu_18_04.id}"
  flavor_id       = "${data.openstack_compute_flavor_v2.s1-2.id}"
  key_pair        = "${openstack_compute_keypair_v2.kubernetes-the-hard-way-keypair.name}"
  security_groups = ["${openstack_compute_secgroup_v2.kubernetes-the-hard-way-allow-external.name}"]

  network {
    name = "Ext-Net",
  }

  network {
    name = "${openstack_networking_network_v2.kubernetes-the-hard-way.name}"
    fixed_ip_v4 = "10.240.0.2${count.index}"
  }

  metadata {
    kubernetes-the-hard-way = "worker"
  }

  provisioner "file" {
    source      = "files/worker-${count.index}_01-ens4.yaml"
    destination = "/tmp/01-ens4.yaml"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/01-ens4.yaml /etc/netplan/01-ens4.yaml",
      "sudo netplan apply",
    ]
    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

}

resource "openstack_compute_instance_v2" "haproxy" {
  name            = "haproxy"
  image_id        = "${data.openstack_images_image_v2.ubuntu_18_04.id}"
  flavor_id       = "${data.openstack_compute_flavor_v2.s1-2.id}"
  key_pair        = "${openstack_compute_keypair_v2.kubernetes-the-hard-way-keypair.name}"
  security_groups = ["${openstack_compute_secgroup_v2.kubernetes-the-hard-way-allow-external.name}"]

  network {
    name = "Ext-Net",
  }

  network {
    name = "${openstack_networking_network_v2.kubernetes-the-hard-way.name}"
    fixed_ip_v4 = "10.240.0.9"
  }

  metadata {
    kubernetes-the-hard-way = "haproxy"
  }

  provisioner "file" {
    source      = "files/haproxy-ens4.yaml"
    destination = "/tmp/01-ens4.yaml"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

  provisioner "file" {
    source      = "scripts/openrc.sh"
    destination = "/tmp/openrc.sh"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

  provisioner "file" {
    source      = "scripts/update_haproxy_conf.sh"
    destination = "/tmp/update_haproxy_conf.sh"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/01-ens4.yaml /etc/netplan/01-ens4.yaml",
      "sudo netplan apply",
      "sudo apt-get install haproxy -y",
    ]
    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

  provisioner "file" {
    source      = "files/haproxy.cfg"
    destination = "/tmp/haproxy.cfg"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }  

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/update_haproxy_conf.sh",
      "sudo /tmp/update_haproxy_conf.sh",
    ]
    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }
}

resource "null_resource" "create_hosts_entries" {
    provisioner "local-exec" {
        command = "scripts/generate_hosts.sh"
    }
    depends_on = ["openstack_compute_instance_v2.workers", "openstack_compute_instance_v2.controllers"]
}

resource "null_resource" "create_certs" {
    provisioner "local-exec" {
        command = "scripts/create_certs.sh"
    }
    depends_on = ["null_resource.create_hosts_entries"]
}

resource "null_resource" "scp_certs" {
    provisioner "local-exec" {
        command = "scripts/scp_certs.sh"
    }
    depends_on = ["null_resource.create_certs"]
}


