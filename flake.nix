{
  description = "Kit - Python project template";

  inputs = {
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      project-name = "kit";
    in {
      devShells.${system}.default = let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ inputs.devshell.overlays.default ];
        };
      in
        pkgs.devshell.mkShell {
          name = project-name;
          motd = "{32}${project-name} activated{reset}\n$(type -p menu &>/dev/null && menu)\n";

          env = [
            {
              name = "PRE_COMMIT_HOME";
              eval = "$PRJ_ROOT/.cache/pre-commit";
            }
          ];

          packages = with pkgs; [
            bubblewrap
            claude-code
            copier
            gh
            pre-commit
            poetry
            python313
            nodejs
          ];
          commands = [
            {
              name = "install-hooks";
              command = ''
                if [[ -f ".pre-commit-config.yaml" ]]; then
                  pushd $PRJ_ROOT
                  pre-commit install --overwrite --install-hooks
                  popd
                fi'';
              help = "install or update pre-commit hooks";
            }
            {
              name = "test-template";
              command = "$PRJ_ROOT/tests/scripts/test-all.sh";
              help = "run full template validation (fresh + update)";
            }
            {
              name = "test-fresh";
              command = "$PRJ_ROOT/tests/scripts/test-fresh.sh \"$@\"";
              help = "test fresh project generation";
            }
            {
              name = "test-update";
              command = "$PRJ_ROOT/tests/scripts/test-update.sh \"$@\"";
              help = "test update path on fixture";
            }
            {
              name = "init-fixture";
              command = "$PRJ_ROOT/tests/scripts/init-fixture.sh";
              help = "initialize the test fixture (run once)";
            }
            {
              name = "validate-templates";
              command = "$PRJ_ROOT/tests/scripts/validate-templates.sh";
              help = "quick syntax validation (no network)";
            }
          ];
        };

      # Quick syntax checks (no network required, suitable for nix flake check)
      checks.${system} = let
        pkgs = import nixpkgs { inherit system; };
      in {
        template-syntax = pkgs.runCommand "template-syntax-check" {
          buildInputs = [ pkgs.python3 pkgs.python3Packages.pyyaml ];
          src = ./.;
        } ''
          cd $src
          ./tests/scripts/validate-templates.sh
          touch $out
        '';
      };

      # Apps for manual testing (require network for poetry/npm)
      apps.${system} = let
        pkgs = import nixpkgs { inherit system; };
        mkApp = script: {
          type = "app";
          program = "${pkgs.writeShellScript "run-test" ''
            export PATH="${pkgs.lib.makeBinPath [
              pkgs.python3
              pkgs.poetry
              pkgs.nodejs
              pkgs.git
              pkgs.copier
            ]}:$PATH"
            exec ${script} "$@"
          ''}";
        };
      in {
        test-template = mkApp "${./tests/scripts/test-all.sh}";
        test-fresh = mkApp "${./tests/scripts/test-fresh.sh}";
        test-update = mkApp "${./tests/scripts/test-update.sh}";
        init-fixture = mkApp "${./tests/scripts/init-fixture.sh}";
        validate-templates = mkApp "${./tests/scripts/validate-templates.sh}";
      };
    };
}
