//
//  ErrorView.swift
//  Interaction
//
//  Created by Marco Mascorro on 9/1/23.
//

import SwiftUI

struct ErrorView: View
{
    internal var body: some View
    {
        VStack(alignment: .center, spacing: 8)
        {
            Spacer()
            
            Image("Shipp")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .shadow(radius: 8)
            
            Text("Interaction is not available")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(24)
        
            Spacer()
        }
    }
}

struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorView()
    }
}
