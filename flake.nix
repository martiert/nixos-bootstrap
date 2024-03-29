{
  description = "Bootstrapping of nixos";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    module = {
      url = "github:martiert/nixos-module";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, module, agenix, home-manager, nixos-hardware }: {
    nixosConfigurations.generic = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        home-manager.nixosModules.home-manager
        module.nixosModules.default
        agenix.nixosModules.default
        ({pkgs, config, ...}: {
          system.stateVersion = "23.05";

          environment.variables.EDITOR = "vim";
          environment.variables.MOZ_ENABLE_WAYLAND = "1";
          environment.systemPackages = [ agenix.packages."x86_64-linux".default ];

          networking.hostName = "perrin";
          age.secrets."wpa_supplicant_enp6s0".file = ../../secrets/wpa_supplicant_wired.age;

          martiert = {
            system = {
              type = "server";
              gpu = "amd";
            };
            mountpoints = {
              root = {
                encryptedDevice = "/dev/disk/by-uuid/34185190-271f-464b-91aa-d6707835ab60";
                device = "/dev/disk/by-uuid/29a4d0df-3ec4-4b32-914a-9329d4b18c99";
                credentials = [
                  "7a1b48e5df7fe3f91fc7b44a5404a6a2"
                  "629a8ce0e10987d16ea20dc186aac48c"
                  "1b633076d0cef092511ad5beca0ab1c5"
                ];
              };
              boot = "/dev/disk/by-uuid/34F2-B158";
              swap = "/dev/disk/by-partuuid/1bc95ed3-d38e-d64e-9410-43067e6cd4d5";
            };
            boot = {
              initrd.extraAvailableKernelModules = [ "usbhid" ];
              efi.removable = true;
            };
            networking = {
              dhcpcd.leaveResolveConf = true;
              interfaces = {
                "eno1" = {
                  enable = true;
                  useDHCP = true;
                };
                "enp6s0" = {
                  enable = true;
                  useDHCP = true;
                  staticRoutes = true;
                  supplicant = {
                    enable = true;
                    wired = true;
                    configFile = config.age.secrets.wpa_supplicant_enp6s0.path;
                  };
                };
              };
              tables = {
                cisco = {
                  number = 42;
                  enable = true;
                  rules = [
                    {
                      from = "192.168.1.1/24";
                    }
                  ];
                  routes = {
                    default = {
                      value = "via 192.168.1.1";
                    };
                  };
                };
              };
            };
            sshd = {
              enable = true;
            };
          };

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.martin = { lib, config, osConfig, ... }: {
              imports = [
                module.nixosModules.home-manager
              ];
              config = {
                martiert = lib.mkDefault osConfig.martiert;
                home.stateVersion = osConfig.system.stateVersion;
              };
            };
          };

          nix = {
            registry.nixpkgs.flake = nixpkgs;
            package = pkgs.nixUnstable;
            extraOptions = ''
              keep-outputs = true
              keep-derivations = true
              experimental-features = nix-command flakes
            '';
          };
        })
      ];
    };
    nixosConfigurations.pinarello = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";

      modules = [
        nixos-hardware.nixosModules.pine64-pinebook-pro
        home-manager.nixosModules.home-manager
        ({pkgs, ... }: {
          environment.variables = {
            EDITOR = "vim";
            MOZ_ENABLE_WAYLAND = "1";
          };
          networking.hostName = "pinarello";

          system.stateVersion = "24.05";
          nix = {
            registry.nixpkgs.flake = nixpkgs;
            package = pkgs.nixUnstable;
            extraOptions = ''
              keep-outputs = true
              keep-derivations = true
              experimental-features = nix-command flakes
            '';
          };

          boot.initrd.luks = {
            devices."root" = {
              device = "/dev/disk/by-uuid/e2fffd54-b835-4e11-8662-9fb595c4900d";
              preLVM = false;
              fallbackToPassword = true;
            };
          };
          fileSystems = {
            "/" = {
              device = "/dev/mapper/root";
              fsType = "ext4";
            };
            "/boot" = {
              device = "/dev/disk/by-uuid/2255-0FAD";
              fsType = "vfat";
            };
          };
          boot.loader.grub.device = "nodev";

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;

            users.martin = { lib, config, osConfig, ... }: {
              config = {
                home.sessionVariables = {
                  EDITOR = "vim";
                };
                home.packages = with pkgs; [
                  silver-searcher
                ];
                home.stateVersion = osConfig.system.stateVersion;
                programs.gpg = {
                  enable = true;
                  settings = {
                    keyserver = "hkps://keys.openpgp.org";
                  };
                  publicKeys = [
                    {
                      source = ./keys.pub;
                      trust = "ultimate";
                    }
                  ];
                };
                services.gpg-agent = {
                  enable = true;
                  pinentryFlavor = "tty";
                  enableSshSupport = true;
                };
                programs.git = {
                  enable = true;
                  userName = "Martin Ertsås";
                  userEmail = "martiert@gmail.com";
                  signing = {
                    signByDefault = true;
                    key = null;
                  };
                  ignores = [
                    "TODO"
                    "compile_commands.json"
                    "shell.nix"
                    ".envrc"
                    ".ccls-cache"
                  ];
                  lfs = {
                    enable = true;
                    skipSmudge = true;
                  };
                  extraConfig = {
                    diff = {
                      renames = true;
                      submodules = "log";
                    };
                    rerere = {
                      enabled = true;
                      autoupdate = true;
                    };
                    grep = {
                      lineNumbers = true;
                    };
                    color = {
                      status = "auto";
                      branch = "auto";
                      diff = "auto";
                      ui = "auto";
                    };
                    push = {
                      default = "simple";
                    };
                    init = {
                      defaultBranch = "main";
                    };
                  };
                };
              };
            };
          };
          nix.settings.trusted-users = [
            "root"
            "martin"
          ];
          networking = {
            useDHCP = false;
            resolvconf.enable = true;
            dhcpcd.extraConfig = "resolv.conf";
          };
          networking.supplicant.wlan0.configFile.writable = true;
          programs.zsh.enable = true;
          users= {
            users = {
              martin = {
                isNormalUser = true;
                extraGroups = [ "wheel" "audio" "video" "uucp" "adbusers" ];
                shell = pkgs.zsh;
                hashedPassword = "$6$nUFj3gT/oPluqWtN$2kfFlSYw7XBlEDlhJgWi2whyWxEuKP7pnquExp7vbBftQiGfzoFtpZ/.exIsnPrv023BFRv7L0RjVzIAJ4e1b0";
              };
              root = {
                password = "changeme";
              };
            };
            groups = {
              martin = {};
            };
          };
          security.sudo.extraConfig = ''
            Defaults targetpw
            Defaults env_keep+="EDITOR LANG LANGUAGE LC_*"
          '';
          services.openssh = {
            enable = true;
            hostKeys = [ { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }];
            settings.PasswordAuthentication = false;
            extraConfig = ''
              StreamLocalBindUnlink yes
            '';
          };
          environment.systemPackages = [
            pkgs.git
          ];
          time.timeZone = "Europe/Oslo";
        })
      ];
    };
    nixosConfigurations.schnappi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";

      modules = [
        module.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          system.stateVersion = "23.05";

          environment.variables = {
            EDITOR = "vim";
            MOZ_ENABLE_WAYLAND = "1";
          };
          networking.hostName = "schnappi";

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;

            users.martin = { lib, config, osConfig, ... }: {
              imports = [
                module.nixosModules.home-manager
              ];
              config = {
                martiert = lib.mkDefault osConfig.martiert;
                home.stateVersion = osConfig.system.stateVersion;
              };
            };
          };
          nix.registry.nixpkgs.flake = nixpkgs;
        }
        {
          nix.settings.trusted-users = [
            "root"
            "martin"
          ];
          networking = {
            useDHCP = false;
            resolvconf.enable = true;
            dhcpcd.extraConfig = "resolv.conf";
          };
          services.rsyslogd.enable = true;
          boot.loader.efi.canTouchEfiVariables = false;

          networking.supplicant.wlan0.configFile.writable = true;

          martiert = {
            system = {
              type = "laptop";
              aarch64.arch = "sc8280xp";
            };
            mountpoints = {
              root = {
                encryptedDevice = "/dev/disk/by-uuid/294031c9-eb35-4151-b78b-fb54af2162bb";
                device = "/dev/mapper/root";
              };
              boot = "/dev/disk/by-uuid/8E25-35C9";
            };
            sshd.enable = true;
            networking = {
              interfaces = {
                "wlan0" = {
                  enable = true;
                  supplicant = {
                    enable = true;
                    configFile = "/etc/wpa_supplicant.conf";
                  };
                  useDHCP = true;
                };
              };
            };
            i3.enable = true;
          };
        }
      ];
    };
  };
}
