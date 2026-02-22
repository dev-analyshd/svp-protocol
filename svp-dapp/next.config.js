/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  typescript: {
    tsconfigPath: './tsconfig.json',
  },
  eslint: {
    dirs: ['pages', 'components', 'lib', 'utils'],
  },
  env: {
    NEXT_PUBLIC_CHAIN_ID: process.env.NEXT_PUBLIC_CHAIN_ID || '1',
    NEXT_PUBLIC_RPC_URL: process.env.NEXT_PUBLIC_RPC_URL || 'http://localhost:8545',
    NEXT_PUBLIC_GOVERNANCE_ADDRESS: process.env.NEXT_PUBLIC_GOVERNANCE_ADDRESS || '',
    NEXT_PUBLIC_TOKEN_ADDRESS: process.env.NEXT_PUBLIC_TOKEN_ADDRESS || '',
    NEXT_PUBLIC_VAULT_ADDRESS: process.env.NEXT_PUBLIC_VAULT_ADDRESS || '',
    NEXT_PUBLIC_DIVIDEND_TRACKER_ADDRESS: process.env.NEXT_PUBLIC_DIVIDEND_TRACKER_ADDRESS || '',
  },
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '*.ipfs.w3s.link',
      },
    ],
  },
};

module.exports = nextConfig;
