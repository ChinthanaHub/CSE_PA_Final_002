# AWS Cost Analysis

## Services Used and Free Tier Eligibility

| Service | Usage | Free Tier | Estimated Monthly Cost |
|---------|-------|-----------|----------------------|
| EKS Cluster | 1 cluster per env | No ($0.10/hr) | ~$72/cluster |
| EC2 (EKS Nodes) | t3.medium x1 Spot (dev) | 750 hrs/month t2.micro only | ~$10 (dev) |
| NAT Gateway | 1x (shared) | No | ~$32 |
| ALB | 1 internal | No | ~$20 |
| KMS | 4 keys + requests | Free for first 20K req | ~$4/month |
| S3 | TF state + logs | 5 GB free | ~$2 |
| DynamoDB | TF state lock | 25 GB free | Free |
| CloudTrail | Management events | 1 trail free | Free |
| GuardDuty | Per-event pricing | 30-day trial | ~$10 (post-trial) |
| Security Hub | Per finding | 30-day trial | ~$5 (post-trial) |
| Secrets Manager | 2 secrets | No | ~$0.80 |
| SNS | Alerts | 1M req/month free | Free |
| CloudWatch | Logs + Metrics | 10 custom metrics free | ~$5 |
| ECR | Container registry | 500 MB/month free | ~$1 |

**Estimated total (dev): ~$162/month**
**Estimated total (prod, larger nodes): ~$400/month**

---

## Cost Optimization Strategies

### Immediate Savings

1. **Use Spot Instances for dev nodes** (60-70% cheaper)
   ```hcl
   capacity_type = "SPOT"
   instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
   ```

2. **Single NAT Gateway for dev** (instead of 3)
   - Saves ~$60/month in dev
   - Acceptable in non-prod (single AZ egress)

3. **Reduce EKS nodes to 1 minimum in dev**
   ```hcl
   node_min_size     = 1
   node_desired_size = 1
   ```

4. **Use AWS Free Tier account for initial development**
   - GuardDuty: 30-day free trial
   - Security Hub: 30-day free trial
   - CloudTrail: First trail is free

### Architecture Optimization for Minimum Cost Demo

For a demo/interview environment (non-HA):

| Component | Cost-Optimized Version | Saving |
|-----------|----------------------|--------|
| NAT Gateway | 1 instead of 3 | -$60 |
| EKS Nodes | t3.small Spot x1 | -$40 |
| GuardDuty | Use trial period | -$10 |
| Security Hub | Use trial period | -$5 |
| CloudWatch | Reduce retention | -$3 |

**Minimum viable demo cost: ~$120/month**

### Free-Tier-Only Alternative Components

| Instead of | Use Free Tier Alternative |
|------------|--------------------------|
| GuardDuty (paid) | CloudTrail + CloudWatch metric filters |
| Security Hub (paid) | AWS Config free rules |
| NAT Gateway x3 | NAT Gateway x1 |
| EKS managed nodes | eksctl with minimal nodes |

---

## Shut Down When Not In Use

```bash
# Scale nodes to 0 when done
aws eks update-nodegroup-config \
  --cluster-name cse-pa-final-dev-cluster \
  --nodegroup-name cse-pa-final-dev-node-group \
  --scaling-config minSize=0,maxSize=4,desiredSize=0

# Restart when needed
aws eks update-nodegroup-config \
  --cluster-name cse-pa-final-dev-cluster \
  --nodegroup-name cse-pa-final-dev-node-group \
  --scaling-config minSize=1,maxSize=4,desiredSize=2
```

This saves the EC2 costs when the cluster is idle. EKS control plane cost ($0.10/hr) continues.
