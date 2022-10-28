//
//  File.swift
//  
//
//  Created by Andrew Stahlman on 10/27/22.
//

import Foundation

public class RemoteVideoInference : NSObject {
    
    public func uploadVideo(file: URL) -> Analysis {
        
        return Analysis(movement: "foo", reps: [
            Rep(startTimestamp: 0, midTimestamp: 1, endTimestamp: 2, analyses: [
                "DEPTH": 3.14
            ])
        ])
    }
    
}
