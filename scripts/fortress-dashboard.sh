show-fortress() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ┌─────────────────────────────────────────────────────────────┐
    │              S3 SECURITY FORTRESS ARCHITECTURE              │
    ├─────────────────────────────────────────────────────────────┤
    │  [Layer 6] MONITORING   ◄── CloudTrail + Config Rules       │
    │  [Layer 5] API ACCESS   ◄── Lambda + Presigned URLs         │
    │  [Layer 4] IMMUTABILITY ◄── Object Lock (Compliance Mode)   │
    │  [Layer 3] ISOLATION    ◄── S3 Access Points                │
    │  [Layer 2] HARDENING    ◄── Public Access Block + Logging   │
    │  [Layer 1] ENCRYPTION   ◄── Customer Managed Keys (KMS)     │
    └─────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
}
