output "governance_bucket_name" {
  description = "Governance mode bucket name"
  value       = module.governance_bucket.bucket_id
}

output "governance_bucket_details" {
  description = "Governance bucket details"
  value = {
    bucket_arn       = module.governance_bucket.bucket_arn
    object_lock_mode = module.governance_bucket.object_lock_mode
    retention_period = module.governance_bucket.retention_period
  }
}

output "compliance_bucket_name" {
  description = "Compliance mode bucket name"
  value       = module.compliance_bucket.bucket_id
}

output "compliance_bucket_details" {
  description = "Compliance bucket details"
  value = {
    bucket_arn       = module.compliance_bucket.bucket_arn
    object_lock_mode = module.compliance_bucket.object_lock_mode
    retention_period = module.compliance_bucket.retention_period
    compliance_level = module.compliance_bucket.compliance_level
  }
}

output "audit_logs_bucket_name" {
  description = "Audit logs bucket name"
  value       = module.audit_logs_bucket.bucket_id
}

output "test_commands" {
  description = "Commands to test object lock"
  value = <<-EOT
    
    Object Lock Test Commands
    
    GOVERNANCE MODE TESTS:
    ---------------------
    
    # 1. Try to delete (should fail)
    aws s3 rm s3://${module.governance_bucket.bucket_id}/test/governance-test.txt
    
    # 2. Delete with bypass (should work if you have permission)
    aws s3api delete-object \
      --bucket ${module.governance_bucket.bucket_id} \
      --key test/governance-test.txt \
      --bypass-governance-retention
    
    # 3. Check object lock status
    aws s3api head-object \
      --bucket ${module.governance_bucket.bucket_id} \
      --key test/governance-test.txt
    
    
    COMPLIANCE MODE TESTS:
    ---------------------
    
    # 1. Try to delete (should fail)
    aws s3 rm s3://${module.compliance_bucket.bucket_id}/records/2024/compliance-record.txt
    
    # 2. Try with bypass (should STILL fail - compliance cannot be bypassed)
    aws s3api delete-object \
      --bucket ${module.compliance_bucket.bucket_id} \
      --key records/2024/compliance-record.txt \
      --bypass-governance-retention
    
    # 3. Check retention date
    aws s3api head-object \
      --bucket ${module.compliance_bucket.bucket_id} \
      --key records/2024/compliance-record.txt \
      --query 'ObjectLockRetainUntilDate'
    
    # 4. Try to extend retention (should work)
    aws s3api put-object-retention \
      --bucket ${module.compliance_bucket.bucket_id} \
      --key records/2024/compliance-record.txt \
      --retention Mode=COMPLIANCE,RetainUntilDate=$(date -u -d '+8 years' +%Y-%m-%dT%H:%M:%SZ)
    
    
    AUDIT LOGS TESTS:
    ----------------
    
    # 1. View object details
    aws s3api head-object \
      --bucket ${module.audit_logs_bucket.bucket_id} \
      --key logs/2024-02-11/app.log
    
    # 2. Try to delete (should fail until retention expires)
    aws s3 rm s3://${module.audit_logs_bucket.bucket_id}/logs/2024-02-11/app.log
    
    
    LEGAL HOLD TESTS:
    ----------------
    
    # 1. Add legal hold to governance object
    aws s3api put-object-legal-hold \
      --bucket ${module.governance_bucket.bucket_id} \
      --key test/governance-test.txt \
      --legal-hold Status=ON
    
    # 2. Check legal hold status
    aws s3api get-object-legal-hold \
      --bucket ${module.governance_bucket.bucket_id} \
      --key test/governance-test.txt
    
    # 3. Remove legal hold (when appropriate)
    aws s3api put-object-legal-hold \
      --bucket ${module.governance_bucket.bucket_id} \
      --key test/governance-test.txt \
      --legal-hold Status=OFF
    
    
    INVENTORY REPORTS:
    -----------------
    
    # Check inventory configuration
    aws s3api list-bucket-inventory-configurations \
      --bucket ${module.compliance_bucket.bucket_id}
    
    # View inventory files (after 24-48 hours)
    aws s3 ls s3://${module.compliance_bucket.bucket_id}/inventory/
    
    ========================================
  EOT
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = <<-EOT
    
    Object Lock Deployment Summary
    
    KMS Key:
    - ID: ${module.kms_key.key_id}
    - ARN: ${module.kms_key.key_arn}
    - Rotation: Enabled
    
    Buckets Created:
    
    1. GOVERNANCE MODE BUCKET
       Name: ${module.governance_bucket.bucket_id}
       Mode: GOVERNANCE
       Retention: 30 days
       Can bypass: Yes (with permission)
       Use case: Testing, internal policies
       Test file: test/governance-test.txt
    
    2. COMPLIANCE MODE BUCKET
       Name: ${module.compliance_bucket.bucket_id}
       Mode: COMPLIANCE
       Retention: 7 years
       Can bypass: NO (immutable)
       Compliance: SEC 17a-4
       Use case: Financial records
       Test file: records/2024/compliance-record.txt
       
       ⚠️  CANNOT delete this bucket until 2031!
    
    3. AUDIT LOGS BUCKET
       Name: ${module.audit_logs_bucket.bucket_id}
       Mode: COMPLIANCE
       Retention: 90 days
       Compliance: SOC 2
       Use case: Audit trails
       Test file: logs/2024-02-11/app.log
    
    Key Differences:
    
    Governance vs Compliance:
    ┌──────────────┬─────────────┬─────────────┐
    │ Feature      │ Governance  │ Compliance  │
    ├──────────────┼─────────────┼─────────────┤
    │ Can delete?  │ With perm   │ Never       │
    │ Can bypass?  │ Yes         │ No          │
    │ Root can?    │ Yes         │ No          │
    │ Use case     │ Testing     │ Regulatory  │
    └──────────────┴─────────────┴─────────────┘
    
    Security Features:
    ✓ KMS encryption on all buckets
    ✓ Versioning enabled (required for Object Lock)
    ✓ Public access blocked
    ✓ Access logging enabled
    ✓ CloudWatch monitoring
    ✓ Daily inventory reports
    ✓ SSL/TLS enforced
    
    Cost Estimate:
    - KMS Key: $1.00/month
    - Storage: $0.023/GB/month (transitions to Glacier)
    - Monitoring: ~$0.50/month
    - Total: ~$1.50-$3/month + storage
    
    Important Notes:
    ⚠️  Object Lock CANNOT be disabled after creation
    ⚠️  Compliance mode objects CANNOT be deleted
    ⚠️  Retention can be extended but not reduced
    ⚠️  Storage costs accumulate (cannot delete)
    
    Next Steps:
    1. Test governance mode (can bypass)
    2. Test compliance mode (cannot bypass)
    3. Add legal hold to objects
    4. Review inventory reports
    5. Update your eraser.io diagram
    
    ========================================
  EOT
}
