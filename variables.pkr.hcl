# Guest OS Configuration

variable "guest_timezone" {
  type        = string
  description = "The timezone for the installed guest operating system"
  default     = "UTC"
}

variable "guest_locale" {
  type        = string
  description = "The locale for the installed guest operating system"
  default     = env("LANG")
}

variable "guest_keyboard_layout" {
  type        = string
  description = "The keyboard layout for the installed guest operating system"
  default     = "us"
}
