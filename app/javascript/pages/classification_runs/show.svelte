<script>
  import Layout from "../Layout.svelte"
  import ClassificationRun from "../components/ClassificationRun.svelte"

  export let classification_run
</script>

<Layout>
  <ClassificationRun run={classification_run} />
</Layout>
