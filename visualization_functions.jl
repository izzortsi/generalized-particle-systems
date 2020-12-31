
function makie_abm(model, ac="#765db4", as=1, am=:circle, scheduler=model.scheduler; resolution=(1280, 720), fps=24, savepath="abm_recording.mp4")
    
    ids = scheduler(model)

    # model-related observables
    modelobs = Observable(model)
    colors = ac isa Function ? Observable(to_color.([ac(model[i]) for i in ids])) : to_color(ac)
    sizes  = as isa Function ? Observable([as(model[i]) for i in ids]) : as
    markers = am isa Function ? Observable([am(model[i]) for i in ids]) : am
    pos = Observable([model[i].pos for i in ids])

    # interaction control observables

    run_obs = Observable{Bool}(false)
    rec_obs = Observable{Bool}(false)
    
    scene, layout = layoutscene(resolution=resolution)
    running_label = LText(scene, lift(x -> x ? "RUNNING" : "HALTED", run_obs))
    recording_label = LText(scene, lift(x -> x ? "RECORDING" : "STOPPED", rec_obs))

    ax1 = layout[1, 1] = LAxis(scene, width=resolution[1] - 100)
    layout[2, 1] = grid!(hcat(running_label, recording_label), tellheight=true, tellwidth=true)

    scatter!(ax1, pos;
    color=colors, markersize=sizes, marker=markers, strokewidth=0.0)

    stream = VideoStream(scene, framerate=fps)

    on(scene.events.keyboardbuttons) do button

        if button == Set(AbstractPlotting.Keyboard.Button[AbstractPlotting.Keyboard.s]) 

            run_obs[] = !run_obs[]
            run_obs[] ? println("Simulation running. $(run_obs[])") : println("Simulation stopped.")

            @async while run_obs[]
                # update observables in scene
                model = modelobs[]
                Agents.step!(model, agent_step!, model_step!, 1)
                ids = scheduler(model)
                update_abm_plot!(pos, colors, sizes, markers, model, ids, ac, as, am)
                
                if !isopen(scene)
                    if !rec_obs[]
                        break
                    else
                        new_filepath = namefile(savepath)
                        save(new_filepath, stream)
                        println("Window closed while recording. Recording stopped. File saved at $new_filepath.")
                        break
                    end
                end

                sleep(1 / fps)
            end
            # end
        
        elseif button == Set(AbstractPlotting.Keyboard.Button[AbstractPlotting.Keyboard.r]) 

            if !rec_obs[]
                # start recording
                # start a new stream and set a new filename for the recording
                stream = VideoStream(scene, framerate=fps)
                #
                rec_obs[] = !rec_obs[]
                println("Recording started.")

                @async while rec_obs[]
                    recordframe!(stream)
                    sleep(1 / fps)
                end

            elseif rec_obs[]
                # save stream and stop recording
                rec_obs[] = !rec_obs[]
                new_filepath = namefile(savepath)
                save(new_filepath, stream)
                println("Recording stopped. File saved at $new_filepath.")
            end
        end
    end

    return scene, ids, colors, sizes, markers, pos, ac, as, am
end

function namefile(savepath)
    timestamp_format = "yy-mm-dd|HH:MM:SS"
    tstamp = Dates.format(now(), timestamp_format)
    dot_idx = findlast(isequal('.'), savepath)
    new_filepath = savepath[1:dot_idx - 1] * "$tstamp" * savepath[dot_idx:end]
    return new_filepath
end

function update_abm_plot!(pos, colors, sizes, markers, model, ids, ac, as, am)
    
    if Agents.nagents(model) == 0
        @warn "The model has no agents, we can't plot anymore!"
        error("The model has no agents, we can't plot anymore!")
    end
    
    pos[] = [model[i].pos for i in ids]
    
    if ac isa Function; colors[] = to_color.([ac(model[i]) for i in ids]); end
    if as isa Function; sizes[] = [as(model[i]) for i in ids]; end
    if am isa Function; markers[] = [am(model[i]) for i in ids]; end
end


