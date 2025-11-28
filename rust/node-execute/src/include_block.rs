use std::path::PathBuf;

use stencila_codecs::DecodeOptions;
use stencila_schema::{Block, CompilationMessage, IncludeBlock, Node};

use crate::prelude::*;

impl Executable for IncludeBlock {
    #[tracing::instrument(skip_all)]
    async fn compile(&mut self, executor: &mut Executor) -> WalkControl {
        // Return early if no source
        // TODO: should also return early if source has not changed since last compile
        if self.source.trim().is_empty() {
            // Continue walk to compile any existing `content`
            return WalkControl::Continue;
        }

        let node_id = self.node_id();
        tracing::trace!("Compiling IncludeBlock {node_id}");

        // Note: We don't evaluate arguments here during compile time because:
        // 1. Expressions like {{site}} may reference variables that don't exist yet (e.g., in ForBlock iterations)
        // 2. Arguments will be evaluated and set during the execute phase when variables are available
        // For now, we just compile the content - argument evaluation happens in execute()

        // Get the content from the source
        let (content, pop_dir, mut messages) =
            source_to_content(&self.source, &self.media_type, executor).await;

        // Add the content to the include block
        if let Some(content) = content {
            self.content = Some(content.clone());
            executor.patch(
                &node_id,
                [
                    // It is important to use `none` and `append` here because
                    // the later retains node ids so they are the same as in `self.content`
                    none(NodeProperty::Content),
                    append(NodeProperty::Content, content),
                ],
            );
        } else {
            self.content = None;
            executor.patch(&node_id, [none(NodeProperty::Content)])
        };

        // Compile the content. This needs to be done here between (possibly)
        // pushing and popping from the directory stack.
        // Arguments are now available as variables in the kernel for the included content
        if let Err(error) = self.content.walk_async(executor).await {
            messages.push(error_to_compilation_message(error));
        };

        // Pop off the directory stack if necessary
        if pop_dir {
            executor.directory_stack.pop();
        }

        let messages = (!messages.is_empty()).then_some(messages);

        self.options.compilation_messages = messages.clone();
        executor.patch(&node_id, [set(NodeProperty::CompilationMessages, messages)]);

        // Break because `content` already compiled above
        WalkControl::Break
    }

    #[tracing::instrument(skip_all)]
    async fn prepare(&mut self, _executor: &mut Executor) -> WalkControl {
        let node_id = self.node_id();
        tracing::trace!("Preparing IncludeBlock {node_id}");

        // Continue walk to prepare nodes in `content`
        WalkControl::Continue
    }

    #[tracing::instrument(skip_all)]
    async fn execute(&mut self, executor: &mut Executor) -> WalkControl {
        let node_id = self.node_id();
        tracing::debug!("Executing IncludeBlock {node_id}: {}", self.source);

        // Evaluate arguments and set them as variables in the kernel before executing content
        // This happens at execution time so variables from ForBlock iterations are available
        if !self.arguments.is_empty() {
            let lang = executor.programming_language(&None);
            let mut kernels = executor.kernels.write().await;
            
            for arg in &self.arguments {
                let arg_name = &arg.name;
                let arg_value = if !arg.code.is_empty() {
                    // Evaluate the code expression (e.g., {{site}} or just site)
                    // Strip {{}} wrapper if present
                    let code_to_eval = arg.code.trim();
                    let code_to_eval = if code_to_eval.starts_with("{{") && code_to_eval.ends_with("}}") {
                        &code_to_eval[2..code_to_eval.len()-2].trim()
                    } else {
                        code_to_eval
                    };
                    
                    // Try to get the value from the kernel (e.g., if code is "site", get variable "site")
                    match kernels.get(code_to_eval).await {
                        Ok(Some(node)) => {
                            tracing::debug!("Evaluated argument '{}' from code '{}' to value", arg_name, code_to_eval);
                            Some(node)
                        }
                        Ok(None) => {
                            // Variable not found in kernel - might not be set yet
                            tracing::debug!("Argument '{}' code '{}' not found in kernel", arg_name, code_to_eval);
                            None
                        }
                        Err(e) => {
                            tracing::warn!("Error getting argument '{}' from kernel: {}", arg_name, e);
                            None
                        }
                    }
                } else if let Some(value) = &arg.value {
                    // Use the literal value
                    Some(value.as_ref().clone())
                } else {
                    None
                };

                if let Some(value) = arg_value {
                    // Set the variable in the kernel with the argument name
                    if let Err(error) = kernels.set(arg_name, &value, lang.as_deref()).await {
                        tracing::warn!("Error setting argument '{}' in kernel: {}", arg_name, error);
                    } else {
                        tracing::debug!("Set argument '{}' in kernel for included content", arg_name);
                    }
                }
            }
            drop(kernels); // Release the lock before continuing
        }

        // Continue walk to execute nodes in `content`
        WalkControl::Continue
    }

    #[tracing::instrument(skip_all)]
    async fn interrupt(&mut self, _executor: &mut Executor) -> WalkControl {
        let node_id = self.node_id();
        tracing::debug!("Interrupting IncludeBlock {node_id}");

        // Continue walk to interrupt nodes in `content`
        WalkControl::Continue
    }
}

// Get the content from a source
async fn source_to_content(
    source: &str,
    media_type: &Option<String>,
    executor: &mut Executor,
) -> (Option<Vec<Block>>, bool, Vec<CompilationMessage>) {
    let mut messages = Vec::new();

    // Resolve the source into a fully qualified URL (including `file://` URL)
    let (identifier, pop_dir) = if source.starts_with("https://") || source.starts_with("http://") {
        (source.to_string(), false)
    } else {
        // Make the path relative to the last directory in the executor's directory stack
        // and update the stack if necessary.
        let last_dir = executor.directory_stack.last();
        let path = last_dir
            .map(|dir| dir.join(source))
            .unwrap_or_else(|| PathBuf::from(source));
        let pop_dir = if let Some(dir) = path.parent() {
            if Some(dir) != last_dir.map(|path_buf| path_buf.as_ref()) {
                executor.directory_stack.push(dir.to_path_buf());
                true
            } else {
                false
            }
        } else {
            false
        };

        (path.to_string_lossy().to_string(), pop_dir)
    };

    // Decode the identifier
    let content: Option<Vec<Block>> = match stencila_codecs::from_identifier(
        &identifier,
        Some(DecodeOptions {
            media_type: media_type.clone(),
            // Set format to None so that the format of the executor's decode options
            // (that of the executor's document) is not used when decoding
            format: None,
            ..executor.decode_options.clone().unwrap_or_default()
        }),
    )
    .await
    {
        Ok(node) => {
            // Transform the decoded node into a blocks
            match node.try_into() {
                Ok(blocks) => Some(blocks),
                Err(error) => {
                    messages.push(CompilationMessage::new(
                        MessageLevel::Error,
                        format!("Unable to convert source into block content: {error}"),
                    ));
                    None
                }
            }
        }
        Err(error) => {
            messages.push(error_to_compilation_message(error));
            None
        }
    };

    // TODO: Implement sub-selecting from included based on `select`

    (content, pop_dir, messages)
}
