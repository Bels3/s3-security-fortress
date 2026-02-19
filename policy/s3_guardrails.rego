package main

import future.keywords.if
import future.keywords.contains

# Rule 1: Versioning (The underscore is safe here because it's not in a 'not')
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_versioning"
    resource.change.after.versioning_configuration[0].status != "Enabled"
    msg := sprintf("🚨 S3 Versioning Violation: %v must be set to 'Enabled'", [resource.address])
}

# Rule 2: KMS Encryption (The fix is here)
deny contains msg if {
    some i
    resource := input.resource_changes[i]
    resource.type == "aws_s3_bucket_server_side_encryption_configuration"
    
    # We name the rule index 'j' and the encryption index 'k' 
    # so OPA can safely evaluate the negation.
    not kms_key_present(resource.change.after.rule)
    
    msg := sprintf("🚨 KMS VIOLATION: %v must use a Customer Managed KMS Key (kms_master_key_id).", [resource.address])
}

kms_key_present(rules) if {
    some j, k
    rules[j].apply_server_side_encryption_by_default[k].kms_master_key_id != null
}
