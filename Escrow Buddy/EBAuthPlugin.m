//
//  EBAuthPlugin.m
//  Escrow Buddy
//
//  Copyright 2023 Netflix
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

//  Based on example from Thomas Burgin.
//  https://github.com/tburgin/PSU_2015

#import "EBAuthPlugin.h"
#import "Escrow_Buddy-Swift.h" // Makes Swift classes available to ObjC

#pragma mark
#pragma mark Entry Point Wrappers

EBAuthPlugin *authorizationPlugin = nil;

static OSStatus PluginDestroy(AuthorizationPluginRef inPlugin) {
    return [authorizationPlugin PluginDestroy:inPlugin];
}

static OSStatus MechanismCreate(AuthorizationPluginRef inPlugin,
                                AuthorizationEngineRef inEngine,
                                AuthorizationMechanismId mechanismId,
                                AuthorizationMechanismRef *outMechanism) {
    return [authorizationPlugin MechanismCreate:inPlugin
                                      EngineRef:inEngine
                                    MechanismId:mechanismId
                                   MechanismRef:outMechanism];
}

static OSStatus MechanismInvoke(AuthorizationMechanismRef inMechanism) {
    return [authorizationPlugin MechanismInvoke:inMechanism];
}

static OSStatus MechanismDeactivate(AuthorizationMechanismRef inMechanism) {
    return [authorizationPlugin MechanismDeactivate:inMechanism];
}

static OSStatus MechanismDestroy(AuthorizationMechanismRef inMechanism) {
    return [authorizationPlugin MechanismDestroy:inMechanism];
}

static AuthorizationPluginInterface gPluginInterface = {
    kAuthorizationPluginInterfaceVersion,
    &PluginDestroy,
    &MechanismCreate,
    &MechanismInvoke,
    &MechanismDeactivate,
    &MechanismDestroy};

extern OSStatus AuthorizationPluginCreate(
    const AuthorizationCallbacks *callbacks, AuthorizationPluginRef *outPlugin,
    const AuthorizationPluginInterface **outPluginInterface) {
    if (authorizationPlugin == nil) {
        authorizationPlugin = [[EBAuthPlugin alloc] init];
    }

    return [authorizationPlugin AuthorizationPluginCreate:callbacks
                                                PluginRef:outPlugin
                                          PluginInterface:outPluginInterface];
}

#pragma mark
#pragma mark EBAuthPlugin Implementation
@implementation EBAuthPlugin

- (OSStatus)AuthorizationPluginCreate:(const AuthorizationCallbacks *)callbacks
                            PluginRef:(AuthorizationPluginRef *)outPlugin
                      PluginInterface:(const AuthorizationPluginInterface **)
                                          outPluginInterface {
    OSStatus err;
    PluginRecord *plugin;

    assert(callbacks != NULL);
    assert(callbacks->version >= kAuthorizationCallbacksVersion);
    assert(outPlugin != NULL);
    assert(outPluginInterface != NULL);

    // Create the plugin.
    err = noErr;
    plugin = (PluginRecord *)malloc(sizeof(*plugin));
    if (plugin == NULL) {
        err = memFullErr;
    }

    // Fill it in.
    if (err == noErr) {
        plugin->fMagic = kPluginMagic;
        plugin->fCallbacks = callbacks;
    }

    *outPlugin = plugin;
    *outPluginInterface = &gPluginInterface;

    assert((err == noErr) == (*outPlugin != NULL));

    return err;
}

- (OSStatus)MechanismCreate:(AuthorizationPluginRef)inPlugin
                  EngineRef:(AuthorizationEngineRef)inEngine
                MechanismId:(AuthorizationMechanismId)mechanismId
               MechanismRef:(AuthorizationMechanismRef *)outMechanism {

    OSStatus err;
    PluginRecord *plugin;
    MechanismRecord *mechanism;

    plugin = (PluginRecord *)inPlugin;
    assert([self PluginValid:plugin]);
    assert(inEngine != NULL);
    assert(mechanismId != NULL);
    assert(outMechanism != NULL);

    err = noErr;
    mechanism = (MechanismRecord *)malloc(sizeof(*mechanism));
    if (mechanism == NULL) {
        err = memFullErr;
    }

    if (err == noErr) {
        mechanism->fMagic = kMechanismMagic;
        mechanism->fEngine = inEngine;
        mechanism->fPlugin = plugin;
        mechanism->fInvoke = (strcmp(mechanismId, "Invoke") == 0);
    }

    *outMechanism = mechanism;

    assert((err == noErr) == (*outMechanism != NULL));

    return err;
}

- (OSStatus)MechanismInvoke:(AuthorizationMechanismRef)inMechanism {
    OSStatus err;
    MechanismRecord *mechanism = (MechanismRecord *)inMechanism;

    if (mechanism->fInvoke) {
        Invoke *invoke = [[Invoke alloc] initWithMechanism:mechanism];
        [invoke run];
    }

    // Default "Allow Login". Used if none of the mechanisms above are called or
    // don't make a decision
    err = mechanism->fPlugin->fCallbacks->SetResult(mechanism->fEngine,
                                                    kAuthorizationResultAllow);
    return err;
}

- (OSStatus)MechanismDeactivate:(AuthorizationMechanismRef)inMechanism {
    OSStatus err;
    MechanismRecord *mechanism;

    mechanism = (MechanismRecord *)inMechanism;
    assert([self MechanismValid:mechanism]);

    err = mechanism->fPlugin->fCallbacks->DidDeactivate(mechanism->fEngine);

    return err;
}

- (OSStatus)MechanismDestroy:(AuthorizationMechanismRef)inMechanism {
    MechanismRecord *mechanism;

    mechanism = (MechanismRecord *)inMechanism;
    assert([self MechanismValid:mechanism]);

    free(mechanism);

    return noErr;
}

- (OSStatus)PluginDestroy:(AuthorizationPluginRef)inPlugin {
    PluginRecord *plugin;

    plugin = (PluginRecord *)inPlugin;
    assert([self PluginValid:plugin]);

    free(plugin);

    return noErr;
}

- (BOOL)MechanismValid:(const MechanismRecord *)mechanism {
    return (mechanism != NULL) && (mechanism->fMagic == kMechanismMagic) &&
           (mechanism->fEngine != NULL) && (mechanism->fPlugin != NULL);
}

- (BOOL)PluginValid:(const PluginRecord *)plugin {
    return (plugin != NULL) && (plugin->fMagic == kPluginMagic) &&
           (plugin->fCallbacks != NULL) &&
           (plugin->fCallbacks->version >= kAuthorizationCallbacksVersion);
}

@end
