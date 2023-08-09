# chose to output the .id instead of the entire vpc object in order to use presumably less memory space. But might modify this later should a different use case emerge
output "vpc-1_id" {
    value = aws_vpc.eu-west-2-vpc-1.id
}
