//
//  ContentView.swift
//  ABB App
//
//  Created by Artem on 28.07.2025.
//

import SwiftUI
import IndustrialKit
import IndustrialKitUI

struct ContentView: View
{
    var body: some View
    {
        TabView
        {
            ConnectView().tabItem { Text("Connect") }
            OutputView().tabItem { Text("Output") }
            MoveView().tabItem { Text("Move") }
            //Gripper().tabItem { Text("Gripper") }
        }
        .padding()
    }
}

struct ConnectView: View
{
    @EnvironmentObject var connector: ABBConnector
    @EnvironmentObject var tool_connector: GripperConnector
    
    @State private var ip: String = "169.254.5.175"
    @State private var port: String = "5000"
    
    @State private var toggle_enabled = true
    @State private var perform_connect = false
    
    //-----
    
    @State private var ip2: String = "169.254.5.175"
    @State private var port2: String = "5001"
    
    @State private var toggle_enabled2 = true
    @State private var perform_connect2 = false
    
    var body: some View
    {
        VStack
        {
            GroupBox("Robot")
            {
                VStack(spacing: 16)
                {
                    HStack
                    {
                        TextField("IP Address", text: $ip)
                        TextField("Port", text: $port)
                            .frame(width: 64)
                    }
                    
                    HStack(spacing: 16)
                    {
                        Toggle(isOn: $perform_connect)
                        {
                            Text(connector.connection_button.label)
                        }
                        .toggleStyle(.button)
                        .controlSize(.large)
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.defaultAction)
                        .onChange(of: perform_connect)
                        { _, new_value in
                            if toggle_enabled
                            {
                                if new_value
                                {
                                    connector.current_parameters = [
                                        .init(name: "IP Address", value: ip),
                                        .init(name: "Port", value: port)
                                    ]
                                    connector.connect()
                                }
                                else
                                {
                                    connector.disconnect()
                                }
                            }
                        }
                        
                        Circle()
                            .foregroundColor(.clear)
                            .glassEffect(.regular.tint(connector.connection_button.color).interactive())
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(10)
            }
            
            GroupBox("Tool")
            {
                VStack(spacing: 16)
                {
                    HStack
                    {
                        TextField("IP Address", text: $ip2)
                        TextField("Port", text: $port2)
                            .frame(width: 64)
                    }
                    
                    HStack(spacing: 16)
                    {
                        Toggle(isOn: $perform_connect2)
                        {
                            Text(tool_connector.connection_button.label)
                        }
                        .toggleStyle(.button)
                        .controlSize(.large)
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.defaultAction)
                        .onChange(of: perform_connect2)
                        { _, new_value in
                            if toggle_enabled2
                            {
                                if new_value
                                {
                                    tool_connector.current_parameters = [
                                        .init(name: "IP Address", value: ip2),
                                        .init(name: "Port", value: port2)
                                    ]
                                    tool_connector.connect()
                                }
                                else
                                {
                                    tool_connector.disconnect()
                                }
                            }
                        }
                        
                        Circle()
                            .foregroundColor(.clear)
                            .glassEffect(.regular.tint(tool_connector.connection_button.color).interactive())
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(10)
            }
            
            GroupBox("Output")
            {
                TextEditor(text: $connector.output)
                    .frame(height: 128)
                    .padding()
            }
        }
        .onAppear
        {
            connector.get_output = true
        }
    }
}

struct OutputView: View
{
    @EnvironmentObject var robot_connector: ABBConnector
    @EnvironmentObject var tool_connector: GripperConnector
    
    @State var output_text: String = "None"
    @State var output_text2: String = "None"
    
    @State private var get_statistics: Bool = false
    @State private var update_interval: Double = 0.01
    @State private var diagram_updated = false
    @State private var diagram_update_task: Task<Void, Never>?
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            HStack
            {
                Text(output_text) //Replace to State View
                
                Text(output_text2) //Replace to State View
            }
            .padding()
            .disabled(!get_statistics)
            
            /*Button("Update")
            {
                update_output()
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)*/
            
            Toggle(isOn: $get_statistics)
            {
                Text("Update")
            }
            .toggleStyle(.checkbox)
            .onChange(of: get_statistics)
            { _, new_value in
                if new_value
                {
                    perform_update()
                }
                else
                {
                    disable_update()
                }
            }
        }
        /*.onAppear()
        {
            if get_statistics
            {
                perform_update()
            }
        }
        .onDisappear()
        {
            disable_update()
        }*/
    }
    
    private func update_output()
    {
        robot_connector.get_output
        { output in
            output_text = String()
            
            if let output = output
            {
                let posision = output.position
                output_text += "📍 TCP position:\n"
                output_text += "XYZ: \(posision.x), \(posision.y), \(posision.z)\n"
                output_text += "RPW: \(posision.r), \(posision.p), \(posision.w)\n"
                
                output_text += "\n"
                
                let state = output.state
                output_text += "📄 State:\n"
                output_text += "processing: \(state.processing)\n"
                output_text += "completed: \(state.completed)\n"
                output_text += "error: \(state.error)"
            }
            else
            {
                output_text = "Cannot read position"
            }
        }
        
        tool_connector.get_output
        { output in
            output_text2 = String()
            
            if let output = output
            {
                output_text2 += "Is opened: \(output.is_opened)\n"
                
                output_text2 += "\n"
                
                let state = output.state
                output_text2 += "📄 State:\n"
                output_text2 += "processing: \(state.processing)\n"
                output_text2 += "completed: \(state.completed)\n"
                output_text2 += "error: \(state.error)"
            }
            else
            {
                output_text2 = "Cannot read position"
            }
        }
    }
    
    private func perform_update(interval: Double = 0.001)
    {
        diagram_updated = true
        
        diagram_update_task = Task
        {
            while diagram_updated
            {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await MainActor.run
                {
                    update_output()
                    //base_workspace.update_view()
                }
                
                if diagram_update_task == nil
                {
                    return
                }
            }
        }
    }
    
    private func disable_update()
    {
        diagram_updated = false
        diagram_update_task?.cancel()
        diagram_update_task = nil
    }
}

struct MoveView: View
{
    @EnvironmentObject var robot_connector: ABBConnector
    @EnvironmentObject var tool_connector: GripperConnector
    
    //@State var position: (x: Float, y: Float, z: Float, r: Float, p: Float, w: Float) = (x: 0, y:0, z:0, r:0, p:90, w:0)
    @State var position: (x: Float, y: Float, z: Float, r: Float, p: Float, w: Float) = (x: 20, y:30, z:30, r:-97, p:-89, w:-37)
    @State var move_type: MoveType = .fine
    @State var move_speed: Float = 50
    
    @State var button_color: Color = .gray
    
    @State var gripper_is_opened = false
    
    var body: some View
    {
        VStack(spacing: 16)
        {
            GroupBox("Parameters")
            {
                VStack(spacing: 16)
                {
                    HStack(spacing: 16)
                    {
                        PositionView(position: $position)
                    }
                    .frame(width: 280)
                    
                    HStack(spacing: 16)
                    {
                        Picker("Type", selection: $move_type)
                        {
                            ForEach(MoveType.allCases, id: \.self)
                            { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 128)
                        .buttonStyle(.borderedProminent)
                        
                        Text("Speed")
                            .frame(width: 40)
                        TextField("0", value: $move_speed, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 48)
                        Stepper("Enter", value: $move_speed, in: 0...100)
                            .labelsHidden()
                    }
                }
                .padding(10)
            }
            
            HStack(spacing: 16)
            {
                Button
                {
                    if button_color == .gray
                    {
                        move_to(point: PositionPoint(x: position.x, y: position.y, z: position.z, r: position.r, p: position.p, w: position.w, move_type: move_type))
                    }
                    
                    //connector.move_to(point: PositionPoint(x: position.x, y: position.y, z: position.z, move_type: move_type))
                }
                label:
                {
                    HStack
                    {
                        Text("Move")
                        
                        if button_color == .gray
                        {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .foregroundStyle(.bar)
                                .frame(width: 16, height: 16)
                        }
                        else
                        {
                            Rectangle()
                                .background(.white)
                                .foregroundStyle(button_color)
                                .frame(width: 16, height: 16)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .glassEffect(in: .rect(cornerRadius: 4))
                        }
                    }
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                
                Toggle(isOn: $gripper_is_opened)
                {
                    Text("Gripper")
                }
                .toggleStyle(.switch)
                .onChange(of: gripper_is_opened)
                { _, new_value in
                    //print(gripper_is_opened)
                    tool_connector.perform(code: gripper_is_opened ? 1 : 0)
                }
            }
        }
    }
    
    private func move_to(point: PositionPoint)
    {
        button_color = .yellow
        robot_connector.move_to(point: point)
        {
            button_color = .green
            
            usleep(500000)
            
            button_color = .gray
        }
    }
}

struct Gripper: View
{
    @State var closed = false
    
    var body: some View
    {
        Toggle("Closed", isOn: $closed)
            .toggleStyle(.switch)
            .padding()
            .onChange(of: closed)
            { _, new_value in
                toggle_gripper(new_value)
            }
    }
    
    func toggle_gripper(_ closed: Bool)
    {
        print(closed)
    }
}

#Preview
{
    ContentView()
        .environmentObject(ABBConnector())
}
