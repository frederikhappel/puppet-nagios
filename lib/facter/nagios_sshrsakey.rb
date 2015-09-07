# return nagios ssh rsa key
keyfile = "/var/nagios/.ssh/id_rsa.pub"
if FileTest.exists?(keyfile)
  Facter.add("nagios_sshrsakey") do
    setcode do
      IO.readlines(keyfile)[0].split()[1]
    end
  end
end