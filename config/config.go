package config

import "time"

type Config struct {
	Port      string
	DBPath    string
	AdminUser string
	AdminPass string
	JWTSecret string
	JWTExpire time.Duration
	UploadDir string
}

var C = Config{
	Port:      "8090",
	DBPath:    "/home/admin/family-ledger/data/family-ledger.db",
	AdminUser: "admin",
	AdminPass: "family2026",
	JWTSecret: "f4m1ly-l3dg3r-s3cr3t-k3y-2026",
	JWTExpire: 72 * time.Hour,
	UploadDir: "/home/admin/family-ledger/uploads",
}
