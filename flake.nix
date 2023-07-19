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
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, module, home-manager, nixos-wsl }: {
    nixosConfigurations.schnappi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";

      modules = [
        module.nixosModules.default
        home-manager.nixosModules.home-manager
        nixos-wsl.nixosModules.wsl
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
