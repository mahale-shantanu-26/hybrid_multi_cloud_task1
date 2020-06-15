// Mentioning the provider
provider "aws" {
  region     = "ap-south-1"
  access_key = ""
  secret_key = ""
}

// Using the resource tls_private_key to generate a private key
resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
}


//Generating Key-Value Pair
resource "aws_key_pair" "generated_key" {
  key_name   = "2002x"
  public_key = tls_private_key.tls_key.public_key_openssh


  depends_on = [
    tls_private_key.tls_key
  ]
}


//Saving keyfile locally
resource "local_file" "key-file" {
  content  = tls_private_key.tls_key.private_key_pem
  filename = "2002x.pem"


  depends_on = [
    tls_private_key.tls_key
  ]
}

// Creating security group
resource "aws_security_group" "allow_80" {
  name        = "allow_80"
  description = "Allow port 80"
ingress {
    description = "incoming http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "incoming ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "sg_allow_80"
  }
}


// Creating the AWS Instance
resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "2002x"
  security_groups = [ "allow_80" ]



  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = tls_private_key.tls_key.private_key_pem
    host = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "thirdos"
  }
}



//Creating EBS volume
resource "aws_ebs_volume" "aws_ebs" {
  availability_zone = aws_instance.web.availability_zone  
  size              = 1

  tags = {
    Name = "TerraformCreated"
  }
}



// Attaching the volume to the instance
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.aws_ebs.id
  instance_id = aws_instance.web.id
  force_detach = true
}

# resource "null_resource" "nullremote3"  {
#   depends_on = [
#     aws_volume_attachment.ebs_att,
#   ]
#   connection {
#     type     = "ssh"
#     user     = "ec2-user"
#     private_key = file("C:/Users/Shantanu/Desktop/Hybrid Multi Cloud/terraform-workspace/2002x.pem")
#     host     = aws_instance.web.public_ip
#   }
#   provisioner "remote-exec" {
#     inline = [
#       "sudo mkfs.ext4  /dev/xvdh",
#       "sudo mount  /dev/xvdh  /var/www/html",
#       "sudo rm -rf /var/www/html/*",
#       "sudo git clone https://github.com/mahale-shantanu-26/hybrid_multi_cloud_task1.git /var/www/html/"
#     ]
#   }
# }


// Creating S3 bucket
resource "aws_s3_bucket" "mybucket" {
  bucket = "my-tf-test-bucket-by-shantanu"
  acl    = "public-read"

  tags = {
    Name        = "Terraform-Created"
    Environment = "Dev"
  }
}

// Creating s3 bucket object for putting files in it
resource "aws_s3_bucket_object" "web-object1" {
  bucket = "${aws_s3_bucket.mybucket.bucket}"
  key    = "servers.jpg"
  source = "servers.jpg"
  acl    = "public-read"
}


// Creating AWS CloudFront Distribution
resource "aws_cloudfront_distribution" "s3-web-distribution" {
  origin {
    domain_name = "${aws_s3_bucket.mybucket.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.mybucket.id}"
  }


  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 Web Distribution"


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.mybucket.id}"


    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Name        = "Web-CloudFront-Distribution"
    Environment = "Production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [
    aws_s3_bucket.mybucket
  ]
}




// Running OS SHell Commands within the instance, which includes cloning project from github
resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,aws_cloudfront_distribution.s3-web-distribution
  ]
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.tls_key.private_key_pem
    host     = aws_instance.web.public_ip
  }


provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/mahale-shantanu-26/hybrid_multi_cloud_task1.git /var/www/html/",
      "sudo sed -i -e 's/cloud-front/${aws_cloudfront_distribution.s3-web-distribution.domain_name}/g' /var/www/html/index.html"
    ]
  }
}

