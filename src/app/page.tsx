"use client"

import { Avatar, Name, Identity, Address, EthBalance, Badge } from "@coinbase/onchainkit/identity";
import { ConnectWallet, WalletDropdown, WalletDropdownLink, WalletDropdownBasename, WalletDropdownDisconnect, Wallet } from "@coinbase/onchainkit/wallet";
import { useAccount, useAccountEffect } from "wagmi";
import { useState } from "react";

export default function Home() {
  const { address } = useAccount();
  const [isConnected, setIsConnected] = useState(false);

  useAccountEffect({
    onConnect: (data) => {
      setIsConnected(true);
      console.log(data);
    },
    onDisconnect: () => setIsConnected(false),
  });

  return (
    <div className="bg-auth-background bg-cover bg-center flex flex-col items-center justify-end h-screen">
      <p className="text-2xl font-bold text-white">Simplifying shared expenses with Transparency, Trust and Crypto</p>
      <Wallet>
        <ConnectWallet className="">
          <Avatar className="h-6 w-6" /> <Name />
          <EthBalance />
        </ConnectWallet>
        <WalletDropdown>
          <Identity className="px-4 pt-3 pb-2" schemaId="0x1" hasCopyAddressOnClick>
            <Avatar />
            <Name>
              <Badge className="badge" />
            </Name>
            <Address />
            <EthBalance />
          </Identity>
          <WalletDropdownLink icon="wallet" href="https://keys.coinbase.com">
            Wallet
          </WalletDropdownLink>
          <WalletDropdownBasename />
          <WalletDropdownDisconnect />
        </WalletDropdown>
      </Wallet>
      <div>
        lmao: {address}
      </div>
    </div>
  );
}
