packer {
  required_plugins {
    qemu = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

locals {
  guest_username = "cloud-user"
  guest_password = "password"
}

source "qemu" "rocky_10" {
  disk_size    = "5G"
  machine_type = "q35"
  memory       = 4096
  cpu_model    = "host"
  cpus         = 2

  cd_content = {
    "ks.cfg" = templatefile("${path.root}/templates/ks.cfg.pkrtpl", {
      username              = local.guest_username
      password              = local.guest_password
      guest_timezone        = var.guest_timezone
      guest_locale          = var.guest_locale
      guest_keyboard_layout = var.guest_keyboard_layout
    })
  }
  cd_label = "OEMDRV"

  shutdown_command = "sudo bash $XDG_RUNTIME_DIR/shutdown.sh"

  communicator = "ssh"
  ssh_username = local.guest_username
  ssh_password = local.guest_password
  ssh_timeout  = "60m"
}

build {
  source "source.qemu.rocky_10" {
    # ISO Configuration
    iso_url      = "https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10-latest-x86_64-minimal.iso"
    iso_checksum = "file:https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10-latest-x86_64-minimal.iso.CHECKSUM"

    # EFI Boot Configuration
    efi_boot = false

    # Boot Configuration
    boot_command = [
      "<up><enter>"
    ]
  }

  # By default QEMU Guest Additions does not allow us to execute commands or get
  # the status of executing commands. We want to be able to do this so that the
  # Molecule driver can execute `cloud-init status --wait` to determine that
  # Cloud-init has finished executing.
  # Even with `guest-exec-status` and `guest-exec` enabled, SELinux also
  # prevents the QEMU Guest Agent from executing the command, so we need to
  # enable the `virt_qemu_ga_read_nonsecurity_files` boolean and also install
  # a custom policy to allow it.
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline_shebang  = "/bin/bash -ex"
    inline = [
      "set -eo pipefail",
      "cat << 'EOF' > /etc/sysconfig/qemu-ga",
      file("${path.root}/files/qemu-ga"),
      "EOF",
      "semanage boolean --modify --on virt_qemu_ga_read_nonsecurity_files",
      "cat << 'EOF' > /run/qemu_guest_agent_cloud_init_module.cil",
      file("${path.root}/files/qemu_guest_agent_cloud_init_module.cil"),
      "EOF",
      "semodule -i /run/qemu_guest_agent_cloud_init_module.cil",
    ]
  }

  # Finally, we drop the shutdown script into the XDG_RUNTIME_DIR so that it can
  # perform cleanup in preparation for use as a template, without being included
  # in the final image.
  provisioner "file" {
    source      = "${path.root}/files/shutdown.sh"
    destination = "$XDG_RUNTIME_DIR/shutdown.sh"
  }
}
