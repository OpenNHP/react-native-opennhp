export const LogLevel: {
  readonly SILENT: 0;
  readonly ERROR: 1;
  readonly INFO: 2;
  readonly DEBUG: 3;
  readonly VERBOSE: 4;
};

export const Cipher: {
  readonly CURVE25519: 0;
  readonly SM2: 1;
};

export const DEFAULT_SERVER_PORT: 62206;

export type LogLevelValue = (typeof LogLevel)[keyof typeof LogLevel] | number;
export type CipherValue = (typeof Cipher)[keyof typeof Cipher] | number;

export type KnockUser = {
  userId?: string;
  deviceId?: string;
  orgId?: string;
  userData?: Record<string, unknown> | string;
};

export type ServerPeer = {
  pubkey: string;
  ip?: string;
  host?: string;
  port?: number;
  expire?: number;
};

export type KnockAck = {
  errCode?: string | number;
  errMsg?: string;
  resHost?: Record<string, string>;
  opnTime?: number;
  aspToken?: string;
  agentAddr?: string;
  acTokens?: Record<string, string>;
  preActions?: Record<string, unknown>;
  redirectUrl?: string;
  raw?: string;
  [key: string]: unknown;
};

export type PublicKeyResult = {
  publicKey: string;
};

export function getDefaultWorkingDirectory(): string;

export function initializeAgent(
  workingDirectory: string,
  logLevel?: LogLevelValue
): Promise<boolean>;

export function close(): Promise<void>;

export function startKnockLoop(): Promise<number>;

export function stopKnockLoop(): Promise<void>;

export function setKnockUser(user?: KnockUser): Promise<boolean>;

export function addServer(server: ServerPeer): Promise<boolean>;

export function removeServer(pubkey: string): Promise<void>;

export function addResource(aspId: string, resId: string, cluster: string): Promise<boolean>;

export function removeResource(aspId: string, resId: string): Promise<void>;

export function knockResource(aspId: string, resId: string, cluster: string): Promise<KnockAck>;

export function exitResource(aspId: string, resId: string, cluster: string): Promise<boolean>;

export function generateKeys(cipher?: CipherValue): Promise<PublicKeyResult>;

export function getPublicKey(): Promise<string>;

export function importAgentKey(options: {
  privateKey: string;
  cipher?: CipherValue;
}): Promise<PublicKeyResult>;

export type RegistrationOptions = {
  workingDirectory: string;
  logLevel?: LogLevelValue;
  cipher?: CipherValue;
  /** Sent as the user id and as UserData.email. The server emails the OTP here. */
  email: string;
  deviceId?: string;
  orgId?: string;
  userData?: Record<string, unknown> | string;
  aspId: string;
  resId: string;
  /** server.toml [[Servers]] Name, or the public key passed to addServer. */
  cluster: string;
};

export type RegistrationResult = {
  errCode?: string;
  errMsg?: string;
  publicKey?: string;
  aspId?: string;
  expiresAt?: number;
  raw?: string;
};

export function requestRegistrationOtp(options: RegistrationOptions): Promise<RegistrationResult>;

export function registerDevice(
  options: RegistrationOptions & { otp: string }
): Promise<RegistrationResult>;
