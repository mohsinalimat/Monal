//
//  SignalCommonCryptoProvider.h
//  Pods
//
//  Created by Chris Ballinger on 6/27/16.
//
//


@import Foundation;
#include "signal_protocol.h"


@interface SignalCommonCryptoProvider : NSObject

- (signal_crypto_provider) cryptoProvider;

@end


