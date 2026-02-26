<?xml version="1.0" encoding="UTF-8"?>
<!--
  Assigns fixed PCI slot addresses to the three VM NICs so the guest OS
  sees predictable interface names regardless of libvirt's default ordering.

    slot 0x03 → NIC1 admin    (enp3s0 on Debian/CentOS/OL, eth0 on Yocto)
    slot 0x04 → NIC2 team0_0  (enp4s0 on Debian/CentOS/OL, eth1 on Yocto)
    slot 0x05 → NIC3 team0_1  (enp5s0 on Debian/CentOS/OL, eth2 on Yocto)

  NOTE: If another libvirt device already occupies slots 0x03–0x05, bump
  these values to 0x06/0x07/0x08 and update the iface_* Terraform variables
  and the sandbox Ansible inventory accordingly.
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <!-- Identity transform -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Strip any existing PCI address elements from interfaces to avoid conflicts -->
  <xsl:template match="devices/interface/address[@type='pci']"/>

  <!-- NIC1 (admin) → slot 0x03 -->
  <xsl:template match="devices/interface[1]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x0"/>
    </xsl:copy>
  </xsl:template>

  <!-- NIC2 (team0_0) → slot 0x04 -->
  <xsl:template match="devices/interface[2]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x0"/>
    </xsl:copy>
  </xsl:template>

  <!-- NIC3 (team0_1) → slot 0x05 -->
  <xsl:template match="devices/interface[3]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x05" function="0x0"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
