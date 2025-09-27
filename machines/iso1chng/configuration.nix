{inputs, ...}: {
  imports = [
    inputs.self.nixosModules.iso
  ];

  networking.hostName = "iso1chng";
}
