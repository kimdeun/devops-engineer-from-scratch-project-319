vpc_name = "vpc_prod"
subnets = {
    public-a  = { zone = "ru-central1-a", cidr = "10.10.1.0/24",  public = true  }
    public-b  = { zone = "ru-central1-b", cidr = "10.10.2.0/24",  public = true  }
    public-d  = { zone = "ru-central1-d", cidr = "10.10.3.0/24",  public = true  }
    private-a = { zone = "ru-central1-a", cidr = "10.10.11.0/24", public = false }
    private-b = { zone = "ru-central1-b", cidr = "10.10.12.0/24", public = false }
    private-d = { zone = "ru-central1-d", cidr = "10.10.13.0/24", public = false }
  }
folder_id = "b1g5vae6a1pu5uvo07it"
bucket_name = "hexlet-backend-kimdeun"
cloud_id = "b1go64chbohn0momgp2e"
