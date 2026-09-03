moved {
  from = aws_eip.this[0]
  to   = aws_eip.this
}

moved {
  from = aws_eip_association.this[0]
  to   = aws_eip_association.this
}
