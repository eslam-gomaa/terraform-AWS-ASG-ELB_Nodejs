
provider "aws" {
  region = "${var.region}"
}


resource "aws_security_group" "terraform" {
  name = "terraform"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "terraform" {
  image_id = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "terraform"
  security_groups = ["${aws_security_group.terraform.id}"]

  user_data =<<-EOF
                 #!/bin/bash
                 sudo yum -y install git mariadb mariadb-server
                 sudo systemctl start  mariadb
                 sudo systemctl enable mariadb
                 sudo mysqladmin -u root password P@ssw0rd
                 cd /tmp
                 wget http://nodejs.org/dist/v0.10.30/node-v0.10.30-linux-x64.tar.gz
                 sudo tar --strip-components 1 -xzvf node-v* -C /usr/local
                 node --version
                 mkdir workspace
                 cd workspace
                 git clone https://github.com/self-tuts/express-todo-app.git
                 cd express-todo-app
                 npm install
                 mysql -u root -pP@ssw0rd -e "create database todo_app;"

cat > app/lib/database.js <<E
var mysql      = require('mysql');

// creating a database connection
var connection = mysql.createConnection({
      host     : 'localhost',
      user     : 'root',
      password : 'P@ssw0rd',
      database : 'todo_app'
});
connection.connect();

module.exports = {
    connection : connection
};
E

                 node app.js

                 EOF
  lifecycle {
    create_before_destroy = true
  }

}


resource "aws_autoscaling_group" "terraform-ASG" {
  launch_configuration = "${aws_launch_configuration.terraform.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  load_balancers = ["${aws_elb.terraform-elb.name}"]
  health_check_type = "ELB"

  max_size = 10
  min_size = 2

  tag {
    key = "name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
}

data "aws_availability_zones" "all" {}


resource "aws_elb" "terraform-elb" {
  name = "terraform-elb"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups = ["${aws_security_group.terraform.id}"]

  "listener" {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    interval = 30
    target = "HTTP:80/"
    timeout = 3
    unhealthy_threshold = 2
  }
}
